import Foundation
import Gardener
import AST
import Parser
import Source
import Sculpture

public class Microscope
{
    public init()
    {
    }

    public func parseFile(path: String) -> TopLevelDeclaration?
    {
        guard File.exists(path) else {return nil}

        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let parts = filename.split(separator: ".")
        guard parts.count == 2 else {return nil}
        let ext = parts[1]
        guard ext == "swift" else {return nil}

        guard let data = File.get(path) else {return nil}
        let s = data.string
        let source = SourceFile(content: s)
        let parser = Parser(source: source)

        guard let topLevelDecl = try? parser.parse() else
        {
            return nil
        }

        return topLevelDecl
    }

    public func convertTypes(top: TopLevelDeclaration) -> [SType]
    {
        return []
    }
}
