module experiments::valid_execution::Simulation

import gen::GeneratorUtils;
import String;
import lang::Builder;
import lang::ExtendedSyntax;
import util::Maybe;
import Message;
import Prelude;
import Type;
//import gen::scala::ScalaGenerator;
import util::Benchmark;
import Type;
import analysis::SimulationHelper;
import shared::iban::Generator;
import shared::http::HttpClient;
import analysis::Simulator;
import analysis::SimulationHelper;

import analysis::CommonAnalysisFunctions;

import experiments::valid_execution::StateBuilder;

set[loc] simple_transaction = {
  |project://rebel-core/examples/simple_transaction/Account.ebl|,
  |project://rebel-core/examples/simple_transaction/Transaction.ebl|
};

set[loc] simple_transaction_extended = {
  |project://rebel-core/examples/simple_transaction_extended/Customer.ebl|,
  |project://rebel-core/examples/simple_transaction_extended/Transaction.ebl|,
  |project://rebel-core/examples/simple_transaction_extended/Account.ebl|
};

public void run(set[loc] specs) {
  set[Built] modules = buildModules(specs);
  
  for (Built built <- modules) {
    testAllTransitions(built, modules);
  }
}

void testAllTransitions(Built built, set[Built] modules) {
  Specification spc = built.normalizedMod.spec;
  map[str, list[StateTo]] stateMap = createStateMap(spc);
  
  for (str stateKey <- stateMap, stateKey notin getInitialStateNames(spc.lifeCycle)) {
    for (StateTo to <- stateMap[stateKey]) {
      for (/VarName via := to.via) {
        println("\nTest transition <via>");
        println("<stateKey> -\> <via> -\> <to.to>");
        testTransition(stateKey, via, to, modules, built, spc);
      }
    }
  }
}

void testTransition(str stateKey, VarName via, StateTo to, set[Built] modules, Built built, Specification spc) {
  EventDef event = getEventByName("<via>", spc.events);
    
  list[State] instanceTraces = buildEntityInstance(built, stateKey, modules);
  
  for(State trace <- instanceTraces) {
    testStateTraceStep(trace, modules);
  }
  
  println();
  
  State currentState = last(instanceTraces);
  EntityInstance instance = findInstanceForTransition(stateKey, currentState.instances, modules);
  
  Var id = getKeyFromInstance(instance, modules);
  
  State current = buildState("12 Jul 2016, 12:00:00", currentState.instances);
  
  printState(current, modules);
  
  loc spec = findSpec(modules, instance.entityType);
  
  list[Var] anyTransitionParams = buildAnyTransitionParams(getTransitionParams(spec, "<via>"));
  list[Variable] transitionParams = buildTransitionParams(instance.entityType, "<via>", "<to.to>",
    id, anyTransitionParams, modules);
    
  map[loc, Type] allResolvedTypes = (() | it + b.resolvedTypes | Built b <- modules);
  
  TransitionResult result = step(instance.entityType, "<via>", transitionParams, current, 
    allSpecsForBuilt(built, modules), allResolvedTypes);
  
  if (successful(State trace) := result) {
    printState(trace, modules);
    testStateTraceStep(trace, modules);
  }
}

void testStateTraceStep(State trace, set[Built] modules) {
  if (step(str entity, str event, list[Variable] transitionParameters) := trace.step) {
    str json = generateJsonForEvent(entity, event, transitionParameters);
    
    Var id = getKeyFromTraceStep(entity, transitionParameters, modules);
    
    str endpoint = "/<last(split(".", entity))>/<id.val>/<capitalize(event)>";
    println("Endpoint: <endpoint>");
    println("JSON payload: <json>");
    
    map[str, str] response = sendPost("/<last(split(".", entity))>/<id.val>/<capitalize(event)>", json);
    println("Response: <response>");
    
    testEntityInstance(trace, id, modules);
    println();
  }
}

void testEntityInstance(State trace, Var id, set[Built] modules) {  
  EntityInstance instance = findInstanceById(trace.instances, id);
  map[str, str] response = sendGet("/<last(split(".", instance.entityType))>/<id.val>");
  
  testStateOfEntityInstance(instance, response, modules);
  
  for(parameter <- instance.vals, !startsWith(parameter.name, "_"), parameter.name != id.fieldName) { 
    parameterInJson = transitionParameterToJson(parameter, last(split(".", instance.entityType)));
    
    if(!contains(response["body"], parameterInJson)) {
      println("Could not find value <parameter.name>, expected  <parameterInJson>");
    }
    
  }
  
}

void testStateOfEntityInstance(EntityInstance instance, map[str, str] response, set[Built] modules) {
  str state = findStateOfInstance(instance, modules);
  str stateInJson = "\"state\":{\"<capitalize(state)>\":{}}";
  
  if(!contains(response["body"], stateInJson)) {
    println("Could not find state <state>, expected  <stateInJson>");
  }
}

str generateJsonForEvent(str entity, str event, list[Variable] transitionParameters) = 
  "{ \"<capitalize("<event>")>\": { <generateTransitionParametersForEvent(entity, [param | param <- transitionParameters, !startsWith(param.name, "_")])> } }";

str generateTransitionParametersForEvent(str entity, []) = "";
str generateTransitionParametersForEvent(str entity, [Variable transitionParameter]) = "<transitionParameterToJson(transitionParameter, entity)>";
str generateTransitionParametersForEvent(str entity, list[Variable] transitionParameters) = "<transitionParameterToJson(head(transitionParameters), entity)>, " + generateTransitionParametersForEvent(entity, tail(transitionParameters));

str transitionParameterToJson(var(str name, Type t, Expr val), str entity) = "\"<name>\":\"<synthesizeTransitionParam(val)>\"" when !startsWith(name, "_");

// methods to synthesize Literal to TransitionParam Literal
str synthesizeTransitionParamLiteral((Literal)`<Money money>`) = "<money.cur> <money.amount>";
str synthesizeTransitionParamLiteral((Literal)`<Percentage p>`) = "<toReal("<p.per>") / 100>";
str synthesizeTransitionParamLiteral((Literal)`<Int p>`) = "<toReal("<p>") / 100>";
str synthesizeTransitionParamLiteral((Literal)`<IBAN iban>`) = "<iban>";

// default methods to synthesize Literal to TransitionParam Literal
default str synthesizeTransitionParamLiteral(Literal lit) {
  println("Failed to synthesize literal <lit>");
  return "<lit>";
}


// methods to synthesize negated Literal to TransitionParam Literal
//str synthesizeNegatedTransitionParamLiteral((Literal)`<Money money>`) = "<money.cur> <money.amount>";
//str synthesizeNegatedTransitionParamLiteral((Literal)`<Percentage p>`) = "<toReal("<p.per>") / 100>";
str synthesizeNegatedTransitionParamLiteral((Literal)`<Money money>`) = "<money.cur> -<money.amount>";
str synthesizeNegatedTransitionParamLiteral((Literal)`<Int p>`) = "-<toReal("<p>") / 100>";

// default methods to synthesize negated Literal to TransitionParam Literal
default str synthesizeNegatedTransitionParamLiteral(Literal lit) {
  println("Failed to synthesize negated literal <lit>");
  return "<lit>";
}

// methods to synthesize Expr to TransitionParam
str synthesizeTransitionParam((Expr)`<Literal lit>`) = synthesizeTransitionParamLiteral(lit);
str synthesizeTransitionParam((Expr)`- <Literal lit>`) = synthesizeNegatedTransitionParamLiteral(lit);

str synthesizeTransitionParam((Expr)`(<Expr exp>)`) = "<synthesizeTransitionParam(exp)>";

// default methods to synthesize Expr to TransitionParam
default str synthesizeTransitionParam(Expr e) {
    println("Failed to synthesize <e>");
    //if (e@\loc in resolvedTypes) println(" (type: <resolvedTypes[e@\loc]>)");
    return "<e>";
}

Var getKeyFromTraceStep(str entity, list[Variable] transitionParameters, set[Built] modules) = head([var(substring(x.name, 1), "<x.val>") |x <- transitionParameters, "_<getKeyFromEntity(entity, modules).name>" == "<x.name>"]);

Var getKeyFromInstance(EntityInstance instance, set[Built] modules) = head([var(x.name, "<x.val>") |x <- instance.vals, "<getKeyFromEntity(instance.entityType, modules).name>" == "<x.name>"]);

str findStateOfInstance(EntityInstance ei, set[Built] modules) = findState(modules, ei.entityType, "<v.val>")
    when v:var("_state", Type _, Expr _) <- ei.vals;
default str findStateOfInstance(EntityInstance ei, set[Built] modules) = "?";

EntityInstance findInstanceForTransition(str stateKey, list[EntityInstance] instances, set[Built] modules) = head([instance |instance <- instances, findStateOfInstance(instance, modules) == stateKey]);

EntityInstance findInstanceById(list[EntityInstance] instances, Var id) = head([instance | instance <- instances, "<id.val>" == intercalate("", instance.id)]);

list[Var] getVarsFromEntityInstance(list[Variable] vals, Var id) = [ var("<x.name>", "<x.val>") | x <- vals, "<x.name>" != "<id.fieldName>"];

list[Var] buildAnyTransitionParams(list[Param] params) = [ var(x.name, "ANY") | x <- params, !startsWith(x.name, "_")];

loc findSpec(set[Built] allSpecs, str entity) = b.normalizedMod.modDef@\loc.top
    when Built b <- allSpecs,
         b has normalizedMod,
         "<b.normalizedMod.modDef.fqn>" == entity;

default loc findSpec(set[Built] allSpecs, str entity) { throw "Unable to locate the specification \'<entity>\'. Is it correctly spelled?"; }

EventDef getEventByName(str event, EventDefs events) {
  list[EventDef] filteredEvents = [e | e <- events.events, "<e.name>" == event];
  assert size(filteredEvents) == 1 : "Multiple events found";
  
  return filteredEvents[0];
}

set[Built] buildModules(set[loc] specifications) {
  mods = loadModules(specifications);
  
  return { b | just(Built b) <- mods};
}

set[Built] allSpecsForBuilt(Built built, set[Built] modules) = {built} + {m | m <- modules, built.normalizedMod.modDef@\loc.top in m.usedBy};

set[str] getInitialStateNames(LifeCycle lc) =
  { "<from.from>" | StateFrom from <- lc.from, /LifeCycleModifier modifier := from && "<modifier>" == "initial" };

map[str, list[StateTo]] createStateMap(Specification spc) {
  map[str, list[StateTo]] stateMap = ();
  
  for (StateFrom from <- spc.lifeCycle.from) {
    stateMap["<from.from>"] = [ t | t <- from.destinations ];
  }
  
  return stateMap;
}