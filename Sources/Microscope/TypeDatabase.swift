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
    var literals: Set<Type> = Set<Type>()
    var named: [String: Type]
    var references: [UInt64: Type]
    var relations: Set<Relation> = Set<Relation>()

    public init()
    {
    }
}
