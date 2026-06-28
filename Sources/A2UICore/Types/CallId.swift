/// サーバ起動の関数呼び出しを一意に識別する ID（A2UI v0.10 `CallId`）。
///
/// `CallFunctionMessage` から対応する `functionResponse` または `error` へそのまま複写する。
public typealias CallId = String
