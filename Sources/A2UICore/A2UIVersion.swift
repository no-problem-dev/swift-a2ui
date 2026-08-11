/// The protocol version written into every encoded message and checked when one is decoded.
///
/// `AgentMessage` and `RendererMessage` refuse a payload whose `version` differs from `current`, so
/// this constant is the single place a version negotiation is decided.
public enum A2UIVersion {
    public static let v1_0 = "v1.0"
    public static let current = v1_0
}
