module experiments::invalid_execution::SMTTestGenerator

import lang::ExtendedSyntax;
import lang::Builder;
import String;
import IO;
import Type;
import List;

void generateTeblFile(loc dest, str lifecycle, StateTo to, VarName via, EventDef event, Built built) { 
  println("\n");
  println(generateSMTCheck(lifecycle, to, via, event, built));
  writeFile(dest, generateSMTCheck(lifecycle, to, via, event, built));
}

str generateSMTCheck(str lifecycle, StateTo to, VarName via, EventDef event, Built built) = 
"module simple_transaction.<testModuleName(lifecycle, to, via)>

import simple_transaction.Account 

state doCheck {
  <to.to> Account <generateThisConditionClause(generateThisConditions(event.pre, built.resolvedTypes))>;
}

check doCheck reachable in max 6 steps;"
;

str testModuleName(str lifecycle, StateTo to, VarName via) = "<capitalize(lifecycle)>To<capitalize("<to.to>")>Via<capitalize("<via>")>Test";

str generateThisConditionClause(list[str] thisConditions) = "with <intercalate(", ", thisConditions)>" when (size(thisConditions) > 0);
default str generateThisConditionClause([]) = "";

list[str] generateThisConditions(Preconditions? pre, map[loc, Type] resolvedTypes) = 
  [ x | c <- p.stats, x <- [generateThisCondition(c, resolvedTypes)], !isEmpty(x) ] when (/Preconditions p := pre);
default list[str] generateThisConditions(Preconditions? pre, map[loc, Type] resolvedTypes) = [];

str generateThisCondition(orig: (Statement)`<Annotations annos> <Expr exp>;`, map[loc, Type] resolvedTypes) {
  str condition = "";
  
  visit (orig) { 
    //case origExp:(Expr)`this.<VarName v>` : condition += "<synthesizeToSMTExp(substituteThisRef(exp), resolvedTypes)>";
    case origExp:(Expr)`this.<VarName v>` : condition += "<synthesizeToSMTExp(exp, resolvedTypes)>";
  }
  
  return condition;
}

//Expr substituteThisRef(Expr e) = visit (e) { case orig:(Expr)`this.<VarName v>` => (Expr)`<VarName v>` };

// methods to synthesize Expr to SMT Expr

str synthesizeToSMTExp((Expr)`<Literal lit>`, map[loc, Type] resolvedTypes) = synthesizeToSMTLiteral(lit);

str synthesizeToSMTVarName((Expr)`this.<VarName lhs>`, map[loc, Type] resolvedTypes) = "<lhs>";

str synthesizeToSMTExp(e:(Expr)`this.<VarName lhs>`, map[loc, Type] resolvedTypes) = synthesizeToSMTVarName(e, resolvedTypes);

str synthesizeToSMTExp(e:(Expr)`this.<VarName lhs> + <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(e.lhs, resolvedTypes)>";
str synthesizeToSMTExp(e:(Expr)`this.<VarName lhs> - <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(e.lhs, resolvedTypes)>";

// default methods to synthesize Expr to SMT Expr

default str synthesizeToSMTExp((Expr)`<Expr lhs> != <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> == <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> == <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> != <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> \> <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> \<= <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> \>= <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> \< <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> \< <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> \>= <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> \<= <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> \> <synthesizeToSMTExp(rhs, resolvedTypes)>";
//default str synthesizeToSMTExp((Expr)`<Expr lhs> in <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(rhs, resolvedTypes)>.contains(<synthesizeToSMTExp(lhs, resolvedTypes)>)";
//default str synthesizeToSMTExp((Expr)`<Expr lhs> && <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> && <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> + <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> + <synthesizeToSMTExp(rhs, resolvedTypes)>";
default str synthesizeToSMTExp((Expr)`<Expr lhs> - <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToSMTExp(lhs, resolvedTypes)> - <synthesizeToSMTExp(rhs, resolvedTypes)>";

default str synthesizeToSMTExp(Expr e, map[loc, Type] resolvedTypes) {
    print("Failed to synthesize <e>");
    //if (e@\loc in resolvedTypes) print(" (type: <resolvedTypes[e@\loc]>)");
    println();
    return "<e>";
}

// methods to synthesize Literal to SMT Literal

str synthesizeToSMTLiteral((Literal)`<Money money>`) = "<money.cur> <money.amount>";

// default methods to synthesize Literal to SMT Literal
default str synthesizeToSMTLiteral(Literal lit) {
  print("Failed to synthesize literal <lit>");
  return "<lit>";
}
