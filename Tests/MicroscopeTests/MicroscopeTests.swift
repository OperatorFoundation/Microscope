import XCTest
@testable import Microscope
import Gardener
import Sculpture

final class MicroscopeTests: XCTestCase {
    func testParseFile() throws
    {
        let factory = OpticsFactory()
        let maybeTop = factory.parseFile(path: "/Users/brandon/swift-ast/Sources/AST/Statement.swift")
        XCTAssertNotNil(maybeTop)
        guard let top = maybeTop else {return}
    }

    func testConvertClassType() throws
    {
        let factory = OpticsFactory()
        let maybeTop = factory.parseFile(path: "/Users/brandon/swift-ast/Sources/AST/Statement/BreakStatement.swift")
        XCTAssertNotNil(maybeTop)
        guard let top = maybeTop else {return}

        let database = TypeDatabase()
        factory.convertTypes(database: database, top: top)
        XCTAssert(database.literals.count != 0)
        XCTAssert(database.relations.count != 0)
    }

    func testConvertClassTypes() throws
    {
        let factory = OpticsFactory()
        let database = TypeDatabase()

        let path = "/Users/brandon/swift-ast/Sources/AST/Statement/"
        let url = URL(string: path)!
        guard let files = File.contentsOfDirectory(atPath: path) else
        {
            XCTFail()
            return
        }

        for file in files
        {
            let parts = file.split(separator: ".")
            guard parts.count == 2 else {continue}
            let ext = parts[1]
            guard ext == "swift" else {continue}

            let filepath = url.appendingPathComponent(file).path
            let maybeTop = factory.parseFile(path: filepath)
            guard let top = maybeTop else
            {
                print("Failed to parse \(filepath)")
                XCTFail()
                return
            }

            factory.convertTypes(database: database, top: top)
        }

        XCTAssert(database.literals.count != 0)
        XCTAssert(database.relations.count != 0)
    }

    func testGenerateStructureMicroscope() throws
    {
        let factory = OpticsFactory()
        let maybeTop = factory.parseFile(path: "/Users/brandon/swift-ast/Sources/AST/Statement/BreakStatement.swift")
        XCTAssertNotNil(maybeTop)
        guard let top = maybeTop else {return}

        let database = TypeDatabase()
        factory.convertTypes(database: database, top: top)
        XCTAssert(database.literals.count != 0)
        XCTAssert(database.named.count != 0)
        XCTAssert(database.relations.count != 0)

        guard let literal = database.named["BreakStatement"] else
        {
            XCTFail()
            return
        }

        switch literal
        {
            case .structure(let structure):
                let lenses = factory.generateStructureMicroscope("AST", structure)
                print(lenses)
            default:
                XCTFail()
                return
        }
    }

    func testWriteStructureMicroscope() throws
    {
        let factory = OpticsFactory()
        let maybeTop = factory.parseFile(path: "/Users/brandon/swift-ast/Sources/AST/Statement/BreakStatement.swift")
        XCTAssertNotNil(maybeTop)
        guard let top = maybeTop else {return}

        let database = TypeDatabase()
        factory.convertTypes(database: database, top: top)
        XCTAssert(database.literals.count != 0)
        XCTAssert(database.named.count != 0)
        XCTAssert(database.relations.count != 0)

        let types: [SType] = database.literals.map
        {
            (literal: LiteralType) -> SType in

            return .literal(literal)
        }

        factory.writeStructureMicroscope(path: "/Users/brandon/Microscope/Sources/SwiftASTOptics/AST/Statement", package: "AST", types: types)
    }

    func testWriteStructureMicroscope_HiddenType() throws
    {
        let factory = OpticsFactory()
        let maybeTop = factory.parseFile(path: "/Users/brandon/swift-ast/Sources/AST/Statement/IfStatement.swift")
        XCTAssertNotNil(maybeTop)
        guard let top = maybeTop else {return}

        let database = TypeDatabase()
        factory.convertTypes(database: database, top: top)
        XCTAssert(database.literals.count != 0)
        XCTAssert(database.named.count != 0)
        XCTAssert(database.relations.count != 0)

        let types: [SType] = database.literals.map
        {
            (literal: LiteralType) -> SType in

            return .literal(literal)
        }

        factory.writeStructureMicroscope(path: "/Users/brandon/Microscope/Sources/SwiftASTOptics/AST/Statement", package: "AST", types: types)
    }


    func testWriteStructureMicroscopes() throws
    {
        let factory = OpticsFactory()

        let path = "/Users/brandon/swift-ast/Sources/AST/Statement/"
        let url = URL(string: path)!
        guard let files = File.contentsOfDirectory(atPath: path) else
        {
            XCTFail()
            return
        }

        for file in files
        {
            let parts = file.split(separator: ".")
            guard parts.count == 2 else {continue}
            let ext = parts[1]
            guard ext == "swift" else {continue}

            let filepath = url.appendingPathComponent(file).path
            let maybeTop = factory.parseFile(path: filepath)
            guard let top = maybeTop else
            {
                print("Failed to parse \(filepath)")
                XCTFail()
                return
            }

            let database = TypeDatabase()
            factory.convertTypes(database: database, top: top)

            let types: [SType] = database.literals.map
            {
                (literal: LiteralType) -> SType in

                return .literal(literal)
            }

            factory.writeStructureMicroscope(path: "/Users/brandon/Microscope/Sources/SwiftASTOptics/AST/Statement", package: "AST", types: types)
        }
    }
}
