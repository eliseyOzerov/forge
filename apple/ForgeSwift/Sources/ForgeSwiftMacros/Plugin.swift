import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ForgeSwiftMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        InitMacro.self,
        CopyMacro.self,
        MergeMacro.self,
        DataMacro.self,
        LerpMacro.self,
        StyleMacro.self,
        ErasedMacro.self,
        MapMacro.self,
        JsonMacro.self,
        StringMacro.self,
        SnapMacro.self,
    ]
}
