module experiments::invalid_execution::EndPointTester

import lang::ExtendedSyntax;
import lang::Builder;
import String;
import IO;
import Type;
import List;
import ParseTree;
import shared::http::HttpClient;

set[VarName] params = {};

map[str, str] executeEvent(str url, str body) {
  return sendPost(url, body);
}

bool isSuccessful(map[str, str] response) {
  return response["isSuccessful"] == "true";
}

str getEndpointForEvent(Specification spc, EventDef event, str key) = "<spc.name>/<key>/<capitalize("<event.name>")>";

str generateJsonEvent(EventDef event, Built built) {
  params = {};
  return "{ \"<capitalize("<event.name>")>\": { <generateTransitionParamsClause(generateTransitionParams(event.pre, built.resolvedTypes))> } }";
}

str generateTransitionParamsClause(list[str] transitionParams) = "<intercalate(", ", transitionParams)>" when (size(transitionParams) > 0);
default str generateTransitionParamsClause([]) = "";

list[str] generateTransitionParams(Preconditions? pre, map[loc, Type] resolvedTypes) = 
  [ x | c <- p.stats, x <- [generateTransitionParam(c, resolvedTypes)], !isEmpty(x) ] when (/Preconditions p := pre);
default list[str] generateTransitionParams(Preconditions? pre, map[loc, Type] resolvedTypes) = [];

str generateTransitionParam(orig: (Statement)`<Annotations annos> <Expr exp>;`, map[loc, Type] resolvedTypes) {
  str condition = "";
  
  visit (orig) {
    case origExp:(Expr)`<VarName var>` : {
      if (var notin params) {
        params = params + var;
        condition += "<synthesizeToTransitionParam(exp, resolvedTypes)>";
      }
    }
  }
  
  return condition;
}

Expr greaterThan((Expr)`<Percentage percentage>`) {
  int val = toInt("<percentage.per>") + 1;
  Percentage newPercentage = parse(#Percentage, "<val>%");
  
  return (Expr)`<Percentage newPercentage>`;
}

default Expr greaterThan(Expr exp) {
  println("Failed to greaterThan <exp>");
  return exp;
}

Expr greaterThanOrEqual((Expr)`<Money money>`) {
  real val = toReal("<money.amount>") + 2;
  
  Expr expr;
  
  if(val < 0 ) {
    expr = parse(#Expr, "- <money.cur> <- val>");
  } else {
    Money newMoney = parse(#Money, "<money.cur> <val>");
    expr = (Expr)`<Money newMoney>`;
  }
  
  return expr;
}

default Expr greaterThanOrEqual(Expr exp) {
  println("Failed to greaterThanOrEqual <exp>");
  return exp;
}

default Expr equal(Expr exp) {
  println("Failed to equal <exp>");
  return exp;
}

default Expr notEqual(Expr exp) {
  println("Failed to notEqual <exp>");
  return exp;
}

Expr lessThanOrEqual((Expr)`<Money money>`) {
  real val = toReal("<money.amount>") - 2;
  
  Expr expr;
  
  if(val < 0 ) {
    expr = parse(#Expr, "- <money.cur> <- val>");
  } else {
    Money newMoney = parse(#Money, "<money.cur> <val>");
    expr = (Expr)`<Money newMoney>`;
  }
  
  return expr;
}

default Expr lessThanOrEqual(Expr exp) {
  println("Failed to lessThanOrEqual <exp>");
  return exp;
}

Expr lessThan((Expr)`<Money money>`) {
  real val = toReal("<money.amount>") - 1;
  Money newMoney = parse(#Money, "<money.cur> <val>");
  
  return (Expr)`<Money newMoney>`;
}

default Expr lessThan(Expr exp) {
  println("Failed to lessThan <exp>");
  return exp;
}

//Expr substituteThisRef(Expr e) = visit (e) { case orig:(Expr)`this.<VarName v>` => (Expr)`<VarName v>` };

// methods to synthesize Expr to TransitionParam

str synthesizeToTransitionParam((Expr)`<Literal lit>`, map[loc, Type] resolvedTypes) = synthesizeToTransitionParamLiteral(lit);
str synthesizeToTransitionParam((Expr)`- <Literal lit>`, map[loc, Type] resolvedTypes) = synthesizeToTransitionParamNegatedLiteral(lit);

str synthesizeToTransitionParamVar((Expr)`<VarName var>`, map[loc, Type] resolvedTypes) = "<var>";

str synthesizeToTransitionParam(e:(Expr)`<VarName var>`, map[loc, Type] resolvedTypes) = synthesizeToTransitionParamVar(e, resolvedTypes);

str synthesizeToTransitionParam((Expr)`<VarName lhs> != <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(equal(rhs), resolvedTypes)>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> == <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(notEqual(rhs), resolvedTypes)>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \> <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(lessThanOrEqual(rhs), resolvedTypes)>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \>= <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(lessThan(rhs), resolvedTypes)>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \< <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(greaterThanOrEqual(rhs), resolvedTypes)>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \<= <Expr rhs>`, map[loc, Type] resolvedTypes) = "\"<lhs>\": \"<synthesizeToTransitionParam(greaterThan(rhs), resolvedTypes)>\"";
//str synthesizeToTransitionParam((Expr)`<VarName lhs> + <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToTransitionParam(rhs, resolvedTypes)>";
//str synthesizeToTransitionParam((Expr)`<VarName lhs> - <Expr rhs>`, map[loc, Type] resolvedTypes) = "<synthesizeToTransitionParam(rhs, resolvedTypes)>";

// default methods to synthesize Expr to TransitionParam
default str synthesizeToTransitionParam(Expr e, map[loc, Type] resolvedTypes) {
    println("Failed to synthesize <e>");
    //if (e@\loc in resolvedTypes) println(" (type: <resolvedTypes[e@\loc]>)");
    return "<e>";
}

// methods to synthesize Literal to TransitionParam Literal
str synthesizeToTransitionParamLiteral((Literal)`<Money money>`) = "<money.cur> <money.amount>";
str synthesizeToTransitionParamLiteral((Literal)`<Percentage p>`) = "<toReal("<p.per>") / 100>";

// default methods to synthesize Literal to TransitionParam Literal
default str synthesizeToTransitionParamLiteral(Literal lit) {
  println("Failed to synthesize literal <lit>");
  return "<lit>";
}

// methods to synthesize negated Literal to TransitionParam Literal
str synthesizeToTransitionParamNegatedLiteral((Literal)`<Money money>`) = "<money.cur> -<money.amount>";

// default methods to synthesize negated Literal to TransitionParam Literal
default str synthesizeToTransitionParamNegatedLiteral(Literal lit) {
  println("Failed to synthesize negated literal <lit>");
  return "<lit>";
}