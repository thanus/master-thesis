module experiments::valid_execution::StateBuilder

import Prelude;
import shared::iban::Generator;
import lang::Builder;
import lang::ExtendedSyntax;
import analysis::tests::ModelCheckerTester;
import analysis::CommonAnalysisFunctions;
import Relation;

loc dest(Built built) = built.normalizedMod.modDef@\loc.parent.top + "EntityInstance.tebl";

list[State] buildEntityInstance(Built built, str stateKey, set[Built] modules) {
  Specification spc = built.normalizedMod.spec;
    
  writeFile(dest(built), generateTebl(built, spc, stateKey, modules));
  return isStateReachable(dest(built), 4);
}

str generateTebl(Built built, Specification spc, str stateKey, set[Built] modules) = 
"module <modulePathOfBuilt(built)>Test

import <modulePathOfBuilt(built)><spc.name>
<generateImportsForReferencedSpec(built, modules)>


state doCheck {
  <stateKey> <spc.name> with <generateKeyForSpecification("<modulePathOfBuilt(built)><spc.name>", modules)>;
  
  <generateReferencedSpecifications(built, modules)>
}

check doCheck reachable in max 4 steps;"
;

str generateImportsForReferencedSpec(Built built, set[Built] modules) {
  lrel[str, str] referencedSpecs = getReferencedSpecs(built, built.normalizedMod.imports);
  
  list[str] specsWithFullName = range(referencedSpecs);
  list[str] imports = ["import <spec>"| spec <- specsWithFullName];
  
  return intercalate("\n", imports);
}

str generateReferencedSpecifications(Built built, set[Built] modules) {
  lrel[str, str] referencedSpecs = getReferencedSpecs(built, built.normalizedMod.imports);
  
  list[str] referencedSpecWithKey = ["<spec[0]> with <generateKeyForSpecification(spec[1], modules)>;"| spec <- referencedSpecs];
  
  return intercalate(" ", referencedSpecWithKey);
}

lrel[str, str] getReferencedSpecs(Built built, imports) = [<"<annos.spc>", findFullyQualifiedNameOfSpec(built.normalizedMod.imports, "<annos.spc>")> | 
    FieldDecl f <- built.normalizedMod.spec.fields.fields, annos <- f.meta.annos, contains("<f.meta>", "@ref")];

str findFullyQualifiedNameOfSpec(imports, name) = "<i.fqn>" when i <- imports, last(split(".", "<i>")) == name;

str modulePathOfBuilt(Built built) = "<built.normalizedMod.modDef.fqn.modulePath>";

str generateKeyForSpecification(str entity, set[Built] allSpecs) {
  tuple[VarName name, Type tipe] key = getKeyFromEntity(entity, allSpecs);
  
  return "<key.name> == <randomValueForType(key.tipe)>";
}

tuple[VarName name, Type tipe] getKeyFromEntity(str entity, set[Built] allSpecs) = <f.name, f.tipe>
    when Built b <- allSpecs, b has normalizedMod, entity == "<b.normalizedMod.modDef.fqn>", FieldDecl f <- b.normalizedMod.spec.fields.fields, "<f.meta>" == "@key"; 

default tuple[VarName name, Type tipe] getKeyFromEntity(str entity, set[Built] allSpecs) { throw "No field with an annotated key field for the \'<entity>\' specification found"; }

str randomValueForType((Type)`IBAN`) = buildRandom();
str randomValueForType((Type)`Integer`) = "<getOneFrom([0..100000])>";
default str randomValueForType(Type t) { throw "Random value for type \'<t>\' not yet implemented"; }