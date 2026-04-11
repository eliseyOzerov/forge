//
//  CreditCardInput.swift
//  ForgeSwift
//
//  TODO: TextField variant with credit card number formatting.
//  Auto-inserts spaces every four digits, validates with Luhn
//  check, maybe detects card network (Visa/Mastercard/etc.) from
//  the prefix.
//

public struct CreditCardInput: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: CreditCardInput")
    }
}
