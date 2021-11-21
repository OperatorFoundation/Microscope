import Foundation
import Gardener
import AST
import Parser
import Source
import Sculpture
import SculptureGenerate

public class OpticsFactory
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

    public func convertTypes(database: TypeDatabase, top: TopLevelDeclaration)
    {
        let visitor = ClassVisitor(database: database)

        do
        {
            let _ = try visitor.traverse(top)
        }
        catch
        {
            return
        }
    }

    public func writeStructureMicroscope(path: String, package: String, types: [SType])
    {
        if !File.exists(path)
        {
            guard File.makeDirectory(atPath: path) else {return}
        }

        let url = URL(fileURLWithPath: path)

        for type in types
        {
            switch type
            {
                case .literal(let literal):
                    switch literal
                    {
                        case .structure(let structure):
                            let name = structure.name
                            let filename = "\(name)Microscope.swift"
                            let filepath = url.appendingPathComponent(filename)
                            let contents = generateStructureMicroscope(package, structure)
                            let _ = File.put(filepath.path, contents: contents.data)
                        default:
                            continue
                    }
                default:
                    continue
            }
        }
    }

    func generateStructureMicroscope(_ package: String, _ structure: Structure) -> String
    {
        let name = structure.name

        let propertyList = structure.properties.compactMap
        {
            (property: Property) -> String? in

            return generatePropertyLens(structure, property)
        }

        let properties = propertyList.joined(separator: "\n")

        let result = """
        import Foundation
        import Focus
        import \(package)

        public class \(name)Microscope
        {
            \(properties)
        }
        """

        return result
    }

    func generatePropertyLens(_ structure: Structure, _ property: Property) -> String?
    {
        let sname = structure.name
        let pname = property.name

        let ptype = typeSource(type: property.type)

        let arglist = structure.properties.compactMap
        {
            (property: Property) -> String? in

            if property.name == pname
            {
                return "\(property.name): value"
            }
            else
            {
                return "\(property.name): structure.\(property.name)"
            }
        }
        let sargs = arglist.joined(separator: ", ")

        let result = """
        var \(pname): SimpleLens<\(sname), \(ptype)> = SimpleLens<\(sname), \(ptype)>(
                get:
                {
                    (structure: \(sname)) -> \(ptype) in

                    return structure.\(pname)
                },

                set:
                {
                    (structure: \(sname), value: \(ptype)) -> \(sname) in

                    return \(sname)(\(sargs))
                }
            )
        """

        return result
    }
}

public enum ConversionOption
{
    case publicOnly
}


class ClassVisitor: ASTVisitor
{
    let database: TypeDatabase
    let options: Set<ConversionOption>

    public init(database: TypeDatabase, options: Set<ConversionOption> = Set<ConversionOption>())
    {
        self.database = database
        self.options = options
    }

    func visit(_ declaration: ClassDeclaration) throws -> Bool
    {
        let identifier = declaration.name
        var maybeName: String? = nil
        switch identifier {
            case .name(let string):
                maybeName = string
            case .backtickedName(let string):
                maybeName = string
            case .wildcard:
                maybeName = nil
        }

        guard let name = maybeName else {return true}

        if self.options.contains(.publicOnly)
        {
            guard let access = declaration.accessLevelModifier else {return true}
            let accessString = access.rawValue
            guard accessString == "public" else {return true}
        }

        if let inheritance = declaration.typeInheritanceClause
        {
            let typeNames = inheritance.typeInheritanceList.compactMap
            {
                (typeIdentifier: TypeIdentifier) -> String? in

                guard typeIdentifier.names.count == 1 else {return nil}
                let identifier = typeIdentifier.names[0].name
                var maybeName: String? = nil
                switch identifier {
                    case .name(let string):
                        maybeName = string
                    case .backtickedName(let string):
                        maybeName = string
                    case .wildcard:
                        return nil
                }
                guard let typeName = maybeName else {return nil}
                return typeName
            }

            let relations = typeNames.enumerated().compactMap
            {
                (index: Int, typeName: String) -> Relation? in

                if index == 0
                {
                    return Relation.implements(Implements(
                        .named(NamedReferenceType(name)),
                        .named(NamedReferenceType(typeName))
                    ))
                }
                else
                {
                    return Relation.inherits(Inherits(
                        .named(NamedReferenceType(name)),
                        .named(NamedReferenceType(typeName))
                    ))
                }
            }

            for relation in relations
            {
                database.addRelation(relation)
            }
        }

        findHiddenTypes(database, declaration)

        let properties = declaration.members.compactMap
        {
            (member: ClassDeclaration.Member) -> Property? in

            switch member
            {
                case .declaration(let declaration):
                    if let constant = declaration as? ConstantDeclaration
                    {
                        if self.options.contains(ConversionOption.publicOnly)
                        {
                            var success: Bool = false
                            for modifier in constant.modifiers
                            {
                                switch modifier
                                {
                                    case .accessLevel(let almod):
                                        switch almod
                                        {
                                            case .public:
                                                success = true
                                            default: return nil
                                        }
                                    default:
                                        return nil
                                }
                            }

                            if !success {return nil}
                        }

                        let initializers = constant.initializerList
                        guard initializers.count == 1 else {return nil}
                        let initializer = initializers[0]
                        let pattern = initializer.pattern
                        guard let ip = pattern as? IdentifierPattern else {return nil}
                        let identifier = ip.identifier
                        var maybeName: String? = nil
                        switch identifier
                        {
                            case .name(let string):
                                maybeName = string
                            case .backtickedName(let string):
                                maybeName = string
                            case .wildcard:
                                maybeName = nil
                        }
                        guard let name = maybeName else {return nil}

                        guard let typeAnnotation = ip.typeAnnotation else {return nil}
                        guard let type = convertTypeAnnotation(typeAnnotation) else {return nil}
                        return Property(name, type: type)
                    }
                    else if let variable = declaration as? VariableDeclaration
                    {
                        if self.options.contains(ConversionOption.publicOnly)
                        {
                            var success: Bool = false
                            for modifier in variable.modifiers
                            {
                                switch modifier
                                {
                                    case .accessLevel(let almod):
                                        switch almod
                                        {
                                            case .public:
                                                success = true
                                            default: return nil
                                        }
                                    default:
                                        return nil
                                }
                            }

                            if !success {return nil}
                        }

                        let body = variable.body
                        switch body
                        {
                            case .initializerList(let initializers):
                                guard initializers.count == 1 else {return nil}
                                let initializer = initializers[0]
                                let pattern = initializer.pattern
                                guard let ip = pattern as? IdentifierPattern else {return nil}
                                let identifier = ip.identifier
                                var maybeName: String? = nil
                                switch identifier
                                {
                                    case .name(let string):
                                        maybeName = string
                                    case .backtickedName(let string):
                                        maybeName = string
                                    case .wildcard:
                                        maybeName = nil
                                }
                                guard let name = maybeName else {return nil}

                                guard let typeAnnotation = ip.typeAnnotation else {return nil}
                                guard let type = convertTypeAnnotation(typeAnnotation) else {return nil}
                                return Property(name, type: type)
                            default:
                                return nil
                        }
                    }
                    else
                    {
                        return nil
                    }
                default:
                    return nil
            }
        }

        let type = LiteralType.structure(Structure(name, properties))
        database.addLiteralType(type)

        database.addNamedType(name, type: type)

        return true
    }

    func convertTypeAnnotation(_ typeAnnotation: TypeAnnotation) -> SType?
    {
        if let otype = typeAnnotation.type as? OptionalType
        {
            let innerType = otype.wrappedType
            guard let typeIdentifier = innerType as? TypeIdentifier else {return nil}
            guard typeIdentifier.names.count == 1 else {return nil}
            let identifier = typeIdentifier.names[0].name
            var maybeName: String? = nil
            switch identifier
            {
                case .name(let string):
                    maybeName = string
                case .backtickedName(let string):
                    maybeName = string
                default:
                    maybeName = nil
            }
            guard let name = maybeName else {return nil}
            let named = SType.named(NamedReferenceType(name))

            let containers = self.database.query(relationSelector: .encapsulates, right: named)
            if containers.count == 0
            {
                return SType.literal(.optional(Optional(.named(NamedReferenceType(name)))))
            }
            else
            {
                guard containers.count == 1 else {return nil}
                let container = containers[0]

                var maybeContainerName: String? = nil
                switch container
                {
                    case .named(let namedContainer):
                        maybeContainerName = namedContainer.name
                    default:
                        maybeContainerName = nil
                }
                guard let containerName = maybeContainerName else {return nil}

                let newName = "\(containerName).\(name)"

                return SType.literal(.optional(Optional(.named(NamedReferenceType(newName)))))
            }
        }
        else if let typeIdentifier = typeAnnotation.type as? TypeIdentifier
        {
            guard typeIdentifier.names.count == 1 else {return nil}
            let identifier = typeIdentifier.names[0].name
            var maybeName: String? = nil
            switch identifier
            {
                case .name(let string):
                    maybeName = string
                case .backtickedName(let string):
                    maybeName = string
                default:
                    maybeName = nil
            }
            guard let name = maybeName else {return nil}
            let named = SType.named(NamedReferenceType(name))

            let containers = self.database.query(relationSelector: .encapsulates, right: named)
            if containers.count == 0
            {
                return SType.named(NamedReferenceType(name))
            }
            else
            {
                guard containers.count == 1 else {return nil}
                let container = containers[0]

                var maybeContainerName: String? = nil
                switch container
                {
                    case .named(let namedContainer):
                        maybeContainerName = namedContainer.name
                    default:
                        maybeContainerName = nil
                }
                guard let containerName = maybeContainerName else {return nil}

                let newName = "\(containerName).\(name)"

                return SType.named(NamedReferenceType(newName))
            }
        }
        else
        {
            return nil
        }
    }

    func findHiddenTypes(_ database: TypeDatabase, _ declaration: ClassDeclaration)
    {
        print(declaration.textDescription)

        let identifier = declaration.name
        var maybeName: String? = nil
        switch identifier {
            case .name(let string):
                maybeName = string
            case .backtickedName(let string):
                maybeName = string
            case .wildcard:
                maybeName = nil
        }

        guard let className = maybeName else {return}

        let enums = declaration.members.compactMap
        {
            (member: ClassDeclaration.Member) -> Choice? in

            switch member
            {
                case .declaration(let declaration):
                    if let enumDeclcaration = declaration as? EnumDeclaration
                    {
                        if self.options.contains(ConversionOption.publicOnly)
                        {
                            var success: Bool = false
                            if let modifier = enumDeclcaration.accessLevelModifier
                            {
                                switch modifier
                                {
                                    case .public:
                                        success = true
                                    default:
                                        success = false
                                }
                            }
                            if !success {return nil}
                        }

                        var maybeEnumName: String? = nil
                        let enumIdentifier = enumDeclcaration.name
                        switch enumIdentifier
                        {
                            case .name(let string):
                                maybeEnumName = string
                            case .backtickedName(let string):
                                maybeEnumName = string
                            case .wildcard:
                                maybeEnumName = nil
                        }
                        guard let enumName = maybeEnumName else {return nil}

                        let enumOptions = enumDeclcaration.members.compactMap
                        {
                            (member: EnumDeclaration.Member) -> Option? in

                            switch member
                            {
                                case .union(let enumCaseWrapper):
                                    guard enumCaseWrapper.cases.count == 1 else {return nil}
                                    let enumCase = enumCaseWrapper.cases[0]

                                    var maybeEnumCaseName: String? = nil
                                    switch enumCase.name
                                    {
                                        case .name(let string):
                                            maybeEnumCaseName = string
                                        case .backtickedName(let string):
                                            maybeEnumCaseName = string
                                        default:
                                            return nil
                                    }
                                    guard let enumCaseName = maybeEnumCaseName else {return nil}

                                    if let tuple = enumCase.tuple
                                    {
                                        let types = tuple.elements.compactMap
                                        {
                                            (element: AST.TupleType.Element) -> SType? in

                                            guard let type = element.type as? TypeIdentifier else {return nil}
                                            let typeNames = type.names
                                            guard typeNames.count == 1 else {return nil}
                                            let typeIdentifier = typeNames[0].name
                                            var maybeTypeName: String? = nil
                                            switch typeIdentifier
                                            {
                                                case .name(let string):
                                                    maybeTypeName = string
                                                case .backtickedName(let string):
                                                    maybeTypeName = string
                                                default:
                                                    maybeTypeName = nil
                                            }
                                            guard let typeName = maybeTypeName else {return nil}

                                            return SType.named(NamedReferenceType(typeName))
                                        }

                                        return Option(enumCaseName, types)
                                    }
                                    else
                                    {
                                        return Option(enumCaseName, [])
                                    }
                                default:
                                    return nil
                            }
                        }

                        return Choice(enumName, enumOptions)
                    }
                default:
                    return nil
            }

            return nil
        }

        for enumType in enums
        {
            database.addLiteralType(.choice(enumType))
            database.addNamedType(enumType.name, type: .choice(enumType))
            database.addRelation(Relation.encapsulates(Encapsulates(.named(NamedReferenceType(className)), .named(NamedReferenceType(enumType.name)))))
        }
    }
}
