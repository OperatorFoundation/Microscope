//
//  File.swift
//  
//
//  Created by Dr. Brandon Wiley on 11/16/21.
//

import Foundation
import Sculpture

public class TypeDatabase
{
    var literals: Set<LiteralType> = Set<LiteralType>()
    var named: [String: LiteralType] = [:]
    var references: [UInt64: ReferenceType] = [:]
    var relations: Set<Relation> = Set<Relation>()

    public init()
    {
    }

    public func addLiteralType(_ type: LiteralType)
    {
        literals.insert(type)
    }

    public func addNamedType(_ name: String, type: LiteralType)
    {
        self.named[name] = type
    }

    public func addRelation(_ relation: Relation)
    {
        relations.insert(relation)
    }

    public func query(relationSelector: Relations, right: SType) -> [SType]
    {
        var results: [SType] = []

        for relation in self.relations
        {
            if (relation.relation == relationSelector) && (relation.right == right)
            {
                results.append(relation.left)
            }
        }

        return results
    }

    public func query(relationSelector: Relations, left: SType) -> [SType]
    {
        var results: [SType] = []

        for relation in self.relations
        {
            if (relation.relation == relationSelector) && (relation.left == left)
            {
                results.append(relation.left)
            }
        }

        return results
    }
}
