/// Font/icon weight, shared between Symbol, Icon, and text.
public enum Weight: Sendable, Equatable {
    case ultraLight, thin, light, regular, medium
    case semibold, bold, heavy, black
    case numeric(Int)
}
