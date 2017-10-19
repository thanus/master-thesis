module experiments::invalid_execution::StateBuilder

import String;
import IO;
import lang::ExtendedSyntax;
import experiments::invalid_execution::EndPointTester;
import experiments::invalid_execution::Main;
import List;
import Type;

set[VarName] params = {};

void constructCurrentState(Specification specification, str key, str stateKey, map[str, list[StateTo]] stateMap) {
  StateTo to = constructInitialState(specification, key, stateKey);
  
  if (stateKey != "<to.to>") {
    constructStateFrom(specification, key, stateKey, stateMap);
  }
  
}

StateTo constructInitialState(Specification specification, str key, str stateKey) {
  StateTo to;
  
  visit(specification.lifeCycle.from) {
    //case (StateFrom)`initial <VarName from> <StateTo* destinations>` : println(); //should work?
    
    case (StateFrom)`<LifeCycleModifier? mo> <VarName from> <StateTo destinations>` : {
      if("<mo>" == "initial") {
        to = destinations;
      
        EventDef event = getEventByName("<destinations.via>", specification.events);
        
        str body = generateValidJsonEvent(event);
        str endpoint = getEndpointForEvent(specification, event, key);
        
        if(stateKey != "<from>") {
          executeEvent(endpoint, body);
        }
        
      }
    }
    
  }
  
  return to;
}

void constructStateFrom(Specification specification, str key, str stateKey, map[str, list[StateTo]] stateMap) {
  for (str stateFrom <- stateMap) {
    for (StateTo to <- stateMap[stateFrom], "<to.to>" == "<stateKey>") {
      println("to to <to>");
      
      VarName via = getOneFrom(getStateVias(to));
      
      EventDef event = getEventByName("<via>", specification.events);
      str body = generateValidJsonEvent(event);
      str endpoint = getEndpointForEvent(specification, event, key);
      
      executeEvent(endpoint, body);
    }
  }
}

list[VarName] getStateVias(StateTo to) = 
  [ x | x <- [via]] when (/VarName via := to.via);

str generateValidJsonEvent(EventDef event) {
  params = {};
  return "{ \"<capitalize("<event.name>")>\": { <generateTransitionParamsClause(generateTransitionParams(event.pre))> } }";
}

str generateTransitionParamsClause(list[str] transitionParams) = "<intercalate(", ", transitionParams)>" when (size(transitionParams) > 0);
default str generateTransitionParamsClause([]) = "";

list[str] generateTransitionParams(Preconditions? pre) = 
  [ x | c <- p.stats, x <- [generateTransitionParam(c)], !isEmpty(x) ] when (/Preconditions p := pre);
default list[str] generateTransitionParams(Preconditions? pre) = [];

str generateTransitionParam(orig: (Statement)`<Annotations annos> <Expr exp>;`) {
  str condition = "";
  
  visit (orig) {
    case origExp:(Expr)`<VarName var>` : {
      if (var notin params) {
        params = params + var;
        condition += "<synthesizeToTransitionParam(exp)>";
      }
    }
  }
  
  return condition;
}

// methods to synthesize Expr to TransitionParam

str synthesizeToTransitionParam((Expr)`<Literal lit>`) = synthesizeToTransitionParamLiteral(lit);
str synthesizeToTransitionParam((Expr)`- <Literal lit>`) = synthesizeToTransitionParamNegatedLiteral(lit);

str synthesizeToTransitionParamVar((Expr)`<VarName var>`) = "<var>";

str synthesizeToTransitionParam(e:(Expr)`<VarName var>`) = synthesizeToTransitionParamVar(e);

str synthesizeToTransitionParam((Expr)`<VarName lhs> != <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(notEqual(rhs))>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> == <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(equal(rhs))>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \> <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(greaterThan(rhs))>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \>= <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(greaterThanOrEqual(rhs))>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \< <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(lessThan(rhs))>\"";
str synthesizeToTransitionParam((Expr)`<VarName lhs> \<= <Expr rhs>`) = "\"<lhs>\": \"<synthesizeToTransitionParam(lessThanOrEqual(rhs))>\"";
//str synthesizeToTransitionParam((Expr)`<VarName lhs> + <Expr rhs>`) = "<synthesizeToTransitionParam(rhs, resolvedTypes)>";
//str synthesizeToTransitionParam((Expr)`<VarName lhs> - <Expr rhs>`) = "<synthesizeToTransitionParam(rhs, resolvedTypes)>";

// default methods to synthesize Expr to TransitionParam
default str synthesizeToTransitionParam(Expr e) {
    println("Failed to synthesize <e>");
    //if (e@\loc in resolvedTypes) println(" (type: <resolvedTypes[e@\loc]>)");
    return "<e>";
}