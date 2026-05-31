import Testing
@testable import A2UIRuntime
import A2UISurface
import A2UICore
import Foundation

@Suite("BasicFunctions: validation")
struct BasicFunctionsValidationTests {

    private func ctx(_ data: StructuredValue = .object([:])) -> DataContext {
        let fns = BasicFunctions()
        return DataContext(dataModel: DataModel(data), functions: fns)
    }

    private func eval(_ call: FunctionCall, _ data: StructuredValue = .object([:])) -> StructuredValue? {
        let fns = BasicFunctions()
        let c = DataContext(dataModel: DataModel(data), functions: fns)
        return fns.evaluate(call, in: c)
    }

    @Test("required: present vs empty")
    func required() {
        #expect(eval(FunctionCall(call: "required", args: ["value": .string("x")])) == .bool(true))
        #expect(eval(FunctionCall(call: "required", args: ["value": .string("")])) == .bool(false))
        #expect(eval(FunctionCall(call: "required", args: ["value": .null])) == .bool(false))
        #expect(eval(FunctionCall(call: "required", args: ["value": .array([])])) == .bool(false))
    }

    @Test("required: resolves a binding before checking")
    func requiredBinding() {
        let call = FunctionCall(call: "required", args: ["value": .object(["path": .string("/email")])])
        #expect(eval(call, .object(["email": .string("a@b.com")])) == .bool(true))
        #expect(eval(call, .object(["email": .string("")])) == .bool(false))
    }

    @Test("regex: matches pattern")
    func regex() {
        let call = FunctionCall(call: "regex", args: ["value": .string("12345"), "pattern": .string("^[0-9]{5}$")])
        #expect(eval(call) == .bool(true))
        let bad = FunctionCall(call: "regex", args: ["value": .string("12a45"), "pattern": .string("^[0-9]{5}$")])
        #expect(eval(bad) == .bool(false))
    }

    @Test("email: valid vs invalid")
    func email() {
        #expect(eval(FunctionCall(call: "email", args: ["value": .string("jane@example.com")])) == .bool(true))
        #expect(eval(FunctionCall(call: "email", args: ["value": .string("not-an-email")])) == .bool(false))
    }

    @Test("length: min/max constraints")
    func length() {
        let call = FunctionCall(call: "length", args: ["value": .string("abcd"), "min": .int(2), "max": .int(5)])
        #expect(eval(call) == .bool(true))
        let tooShort = FunctionCall(call: "length", args: ["value": .string("a"), "min": .int(2)])
        #expect(eval(tooShort) == .bool(false))
    }

    @Test("numeric: range + non-numeric")
    func numeric() {
        let call = FunctionCall(call: "numeric", args: ["value": .string("42"), "min": .int(0), "max": .int(100)])
        #expect(eval(call) == .bool(true))
        let nan = FunctionCall(call: "numeric", args: ["value": .string("abc")])
        #expect(eval(nan) == .bool(false))
    }

    @Test("and / or / not")
    func logical() {
        let andCall = FunctionCall(call: "and", args: ["values": .array([.bool(true), .bool(true)])])
        #expect(eval(andCall) == .bool(true))
        let andFalse = FunctionCall(call: "and", args: ["values": .array([.bool(true), .bool(false)])])
        #expect(eval(andFalse) == .bool(false))
        let orCall = FunctionCall(call: "or", args: ["values": .array([.bool(false), .bool(true)])])
        #expect(eval(orCall) == .bool(true))
        let notCall = FunctionCall(call: "not", args: ["value": .bool(false)])
        #expect(eval(notCall) == .bool(true))
    }

    @Test("nested logical with binding (spec button validation pattern)")
    func nestedLogical() {
        // and(required(/terms), or(required(/email), required(/phone)))
        // Note: per spec, `required` checks *presence* (not null/empty/empty-array). A boolean
        // `false` IS present, so a checkbox pattern uses an empty/absent value for "not accepted".
        let call = FunctionCall(call: "and", args: ["values": .array([
            .object(["call": .string("required"), "args": .object(["value": .object(["path": .string("/terms")])])]),
            .object(["call": .string("or"), "args": .object(["values": .array([
                .object(["call": .string("required"), "args": .object(["value": .object(["path": .string("/email")])])]),
                .object(["call": .string("required"), "args": .object(["value": .object(["path": .string("/phone")])])]),
            ])])]),
        ])])
        // terms accepted (non-empty) + email present → true
        #expect(eval(call, .object(["terms": .string("yes"), "email": .string("a@b.com"), "phone": .string("")])) == .bool(true))
        // terms absent/empty → false
        #expect(eval(call, .object(["terms": .string(""), "email": .string("a@b.com")])) == .bool(false))
        // terms ok but neither email nor phone → false
        #expect(eval(call, .object(["terms": .string("yes"), "email": .string(""), "phone": .string("")])) == .bool(false))
    }
}

@Suite("BasicFunctions: formatting")
struct BasicFunctionsFormattingTests {

    private func eval(_ call: FunctionCall, _ data: StructuredValue = .object([:]), locale: Locale = Locale(identifier: "en_US")) -> StructuredValue? {
        let fns = BasicFunctions(locale: locale)
        let c = DataContext(dataModel: DataModel(data), functions: fns)
        return fns.evaluate(call, in: c)
    }

    @Test("formatNumber: decimals and grouping")
    func formatNumber() {
        let call = FunctionCall(call: "formatNumber", args: ["value": .double(1234.5), "decimals": .int(2)])
        #expect(eval(call) == .string("1,234.50"))
    }

    @Test("formatCurrency: USD")
    func formatCurrency() {
        let call = FunctionCall(call: "formatCurrency", args: ["value": .double(9.99), "currency": .string("USD")])
        // en_US USD → $9.99
        #expect(eval(call) == .string("$9.99"))
    }

    @Test("formatDate: ISO input + TR35 pattern")
    func formatDate() {
        let call = FunctionCall(call: "formatDate", args: [
            "value": .string("2026-02-02T15:17:00Z"),
            "format": .string("yyyy-MM-dd"),
        ])
        #expect(eval(call) == .string("2026-02-02"))
    }

    @Test("pluralize: English one vs other")
    func pluralize() {
        let one = FunctionCall(call: "pluralize", args: ["value": .int(1), "one": .string("item"), "other": .string("items")])
        #expect(eval(one) == .string("item"))
        let many = FunctionCall(call: "pluralize", args: ["value": .int(5), "one": .string("item"), "other": .string("items")])
        #expect(eval(many) == .string("items"))
    }
}

@Suite("FormatStringEngine")
struct FormatStringEngineTests {

    private func ctx(_ data: StructuredValue) -> DataContext {
        DataContext(dataModel: DataModel(data), functions: BasicFunctions())
    }

    @Test("interpolates absolute data path")
    func absolutePath() {
        let c = ctx(.object(["user": .object(["firstName": .string("Jane")]), "appName": .string("Delish")]))
        let out = FormatStringEngine.evaluate("Hello, ${/user/firstName}! Welcome to ${/appName}.", in: c, functions: BasicFunctions())
        #expect(out == "Hello, Jane! Welcome to Delish.")
    }

    @Test("relative path resolves against scope")
    func relativePath() {
        let dm = DataModel(.object(["employees": .array([.object(["name": .string("Alice")])])]))
        let c = DataContext(dataModel: dm, path: "/employees/0", functions: BasicFunctions())
        let out = FormatStringEngine.evaluate("Name: ${name}", in: c, functions: BasicFunctions())
        #expect(out == "Name: Alice")
    }

    @Test("escaped marker yields literal")
    func escaped() {
        let c = ctx(.object([:]))
        let out = FormatStringEngine.evaluate("Price is \\${5}", in: c, functions: BasicFunctions())
        #expect(out == "Price is ${5}")
    }

    @Test("nested function call with explicit binding arg")
    func nestedFunction() {
        let c = ctx(.object(["currentDate": .string("2026-02-02T00:00:00Z")]))
        let out = FormatStringEngine.evaluate(
            "Date: ${formatDate(value:${/currentDate}, format:'yyyy-MM-dd')}",
            in: c, functions: BasicFunctions()
        )
        #expect(out == "Date: 2026-02-02")
    }

    @Test("missing path interpolates as empty string")
    func missingPathEmpty() {
        let c = ctx(.object([:]))
        let out = FormatStringEngine.evaluate("X=${/nope}.", in: c, functions: BasicFunctions())
        #expect(out == "X=.")
    }

    @Test("formatString function entrypoint")
    func viaFunctionCall() {
        let fns = BasicFunctions()
        let c = DataContext(dataModel: DataModel(.object(["n": .string("World")])), functions: fns)
        let call = FunctionCall(call: "formatString", args: ["value": .string("Hi ${/n}!")])
        #expect(fns.evaluate(call, in: c) == .string("Hi World!"))
    }
}

@Suite("ChecksEvaluator")
struct ChecksEvaluatorTests {

    @Test("first failing check message is returned")
    func firstFailure() {
        let fns = BasicFunctions()
        let dm = DataModel(.object(["email": .string("")]))
        let c = DataContext(dataModel: dm, functions: fns)
        let checks = [
            CheckRule(
                condition: .functionCall(FunctionCall(call: "required", args: ["value": .object(["path": .string("/email")])])),
                message: "Email is required."
            )
        ]
        #expect(ChecksEvaluator.firstFailure(checks, in: c) == "Email is required.")
    }

    @Test("all pass → nil")
    func allPass() {
        let fns = BasicFunctions()
        let dm = DataModel(.object(["email": .string("a@b.com")]))
        let c = DataContext(dataModel: dm, functions: fns)
        let checks = [
            CheckRule(
                condition: .functionCall(FunctionCall(call: "required", args: ["value": .object(["path": .string("/email")])])),
                message: "Email is required."
            )
        ]
        #expect(ChecksEvaluator.firstFailure(checks, in: c) == nil)
        #expect(ChecksEvaluator.allPass(checks, in: c) == true)
    }
}
