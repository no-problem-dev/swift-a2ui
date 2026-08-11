/// Pairs one agent-initiated function call with the reply it produces (A2UI v1.0 `CallId`).
///
/// It is a bare `String`, so nothing stops a reply from carrying the wrong one: copy it verbatim
/// out of the `CallFunctionMessage` into the matching `functionResponse` or `error`.
public typealias CallId = String
