module experiments::invalid_execution::Main

import gen::GeneratorUtils;
import lang::Builder;
import lang::ExtendedSyntax;
import util::Maybe;
import Message;
import Prelude;
import Type;
import gen::scala::ScalaGenerator;
import util::Benchmark;
import Type;
import experiments::invalid_execution::SMTTestGenerator;
import experiments::invalid_execution::EndPointTester;
import shared::iban::Generator;
import experiments::invalid_execution::StateBuilder;
import util::ShellExec;
import util::Resources;
import analysis::tests::ModelCheckerTester;

loc spec = |project://rebel-core/examples/simple_transaction/Account.ebl|;

public void run() {
  startGeneratedSystem();

  set[Built] modules = buildModules({spec});
  
  for (Built built <- modules) {
    Specification spc = built.inlinedMod.spec;
    map[str, list[StateTo]] stateMap = createStateMap(spc);
    
    for (str stateKey <- stateMap) {
      for (StateTo to <- stateMap[stateKey]) {
      
        for (/VarName via := to.via) {
          println("\nTest transition <via>");
          println("<stateKey> -\> <via> -\> <to.to>");
          
          testTransition(stateKey, via, to, built, spc, stateMap);
        }
      }
    }
    
  }
}

void testTransition(str stateKey, VarName via, StateTo to, Built built, Specification spc, map[str, list[StateTo]] stateMap) {
  EventDef event = getEventByName("<via>", spc.events);
  
  loc dest = |project://rebel-core/examples/simple_transaction/<testModuleName(stateKey, to, via)>.tebl|;
  generateTeblFile(dest, stateKey, to, via, event, built);
  println("generated <via> test in <dest>");
  
  bool reachabilityTransition = testIfStateIsReachable(dest, 7);
  println("Reachability transition: <reachabilityTransition>");
  
  str iban = buildRandom();
  constructCurrentState(spc, iban, stateKey, stateMap);
  
  str body = generateJsonEvent(event, built);
  println("body: <body>");
  str endpoint = getEndpointForEvent(spc, event, iban);
  
  response = executeEvent(endpoint, body);
  println("Response: <response>");
  
  bool successfulTransition = isSuccessful(response);
  println("Execute transition result: <successfulTransition>");
  
  println("Result successful transition test: <reachabilityTransition == successfulTransition>");
}

void startGeneratedSystem() {
  startScalaSystem();
  //startJavaSystem();
}

void startScalaSystem() {
  loc dest = |project://rebel-core/target/code/scala|;
  PID pidCassandra = createProcess("/usr/local/bin/sbt", workingDir=location(dest), args=["cassandra"]);
  
  str outputCassandra = readFrom(pidCassandra);
  
  while(!contains(outputCassandra, "StartupChecks")) {
    outputCassandra = readFrom(pidCassandra);
    print(outputCassandra);
  }
  
  PID pidRun1 = createProcess("/usr/local/bin/sbt", workingDir=location(dest), args=["run1"]);
  str outputRun1 = readFrom(pidCassandra);
  
  while(!contains(outputRun1, "Started REST end points")) {
    outputRun1 = readFrom(pidRun1);
    print(outputRun1);
  }
}

void startJavaSystem() {
  loc dest = |project://ing-rebel-generators/skeletons/javadatomic|;
  PID pidMvn = createProcess("/usr/local/bin/mvn", workingDir=location(dest), args=["package", "-P", "dist"]);
  
  str outputMvn = readFrom(pidMvn);
  
  while(!contains(outputMvn, "BUILD SUCCESS")) {
    outputMvn = readFrom(pidMvn);
    print(outputMvn);
  }
  
  loc destJar = |project://ing-rebel-generators/skeletons/javadatomic/monolith-app-generated/target|;
  
  PID pidJava = createProcess("java", workingDir=location(destJar), args=["-jar", "monolith-app-generated-1.0-SNAPSHOT.jar"]);
  str outputJava = readFrom(pidJava);
  
  while(!contains(outputJava, "Started CoreBankServer")) {
    outputJava = readFrom(pidJava);
    print(outputJava);
  }
}

EventDef getEventByName(str event, EventDefs events) {
  list[EventDef] filteredEvents = [e | e <- events.events, "<e.name>" == event];
  assert size(filteredEvents) == 1 : "Multiple events found";
  
  return filteredEvents[0];
}

set[Built] buildModules(set[loc] specifications) {
  mods = loadModules(specifications);
  
  return { b | just(Built b) <- mods};
}

map[str, list[StateTo]] createStateMap(Specification spc) {
  map[str, list[StateTo]] stateMap = ();
  
  for (StateFrom from <- spc.lifeCycle.from) {
    stateMap["<from.from>"] = [ t | t <- from.destinations ];
  }
  
  return stateMap;
}
