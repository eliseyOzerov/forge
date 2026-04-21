import SwiftSyntax
import SwiftSyntaxMacros

/// `@Copy` generates fluent copy helpers for structs:
///
///     @Copy
///     struct BoxStyle {
///         var frame: Frame
///         var surface: Surface?
///     }
///
/// Expands to per-property setters **and** a closure-based `copy`:
///
///     func frame(_ value: Frame) -> BoxStyle { var c = self; c.frame = value; return c }
///     func surface(_ value: Surface?) -> BoxStyle { var c = self; c.surface = value; return c }
///     func copy(_ mutate: (inout BoxStyle) -> Void) -> BoxStyle { var c = self; mutate(&c); return c }
public struct CopyMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = storedProperties(of: declaration)
        let typeName = typeName(of: declaration)

        var decls: [DeclSyntax] = properties.map { prop in
            """
            public func \(raw: prop.name)(_ value: \(raw: prop.type)) -> \(raw: typeName) { var c = self; c.\(raw: prop.name) = value; return c }
            """
        }

        decls.append(
            """
            public func copy(_ mutate: (inout \(raw: typeName)) -> Void) -> \(raw: typeName) { var c = self; mutate(&c); return c }
            """
        )

        return decls
    }
}

// MARK: - Helpers

struct StoredProperty {
    let name: String
    let type: String
}

func typeName(of declaration: some DeclGroupSyntax) -> String {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
        return structDecl.name.text
    }
    if let classDecl = declaration.as(ClassDeclSyntax.self) {
        return classDecl.name.text
    }
    return "_Self"
}

func storedProperties(of declaration: some DeclGroupSyntax) -> [StoredProperty] {
    declaration.memberBlock.members.compactMap { member -> StoredProperty? in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.text == "var" else { return nil }

        // Skip computed properties (those with accessors that aren't just willSet/didSet)
        guard let binding = varDecl.bindings.first else { return nil }
        if let accessors = binding.accessorBlock {
            switch accessors.accessors {
            case .getter:
                return nil // shorthand computed property
            case .accessors(let list):
                let kinds = list.map { $0.accessorSpecifier.text }
                if kinds.contains("get") || kinds.contains("set") { return nil }
            }
        }

        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type.trimmedDescription else {
            return nil
        }

        return StoredProperty(name: name, type: type)
    }
}
