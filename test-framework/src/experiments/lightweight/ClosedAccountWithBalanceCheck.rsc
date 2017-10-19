module experiments::lightweight::ClosedAccountWithBalanceCheck

import analysis::ModelChecker;
import analysis::tests::ModelCheckerTester;
import analysis::CommonAnalysisFunctions;

import shared::http::HttpClient;

import shared::iban::Generator;

import IO;
import String;

loc checkLocation = |project://rebel-core/examples/simple_transaction/ClosedAccountWithBalance.tebl|;
bool testIfStateIsReachable() = testIfStateIsReachable(checkLocation, 7);

str iban = buildRandom();

public bool check() {
  copyState();
  
  bool reachableState = testIfStateIsReachable();
  println("Reachable state <reachableState>");
  
  openAccount();
  
  bool closedAccount = isSuccessful(closeAccount());
  println("Closed account <closedAccount>");
  
  return reachableState == closedAccount;
}

private void openAccount() {
  str body = "{ \"OpenAccount\": { \"initialDeposit\": \"EUR 50.00\" } }";

  sendPost("Account/<iban>/OpenAccount", body);
}

private map[str, str] closeAccount() {
  str body = "{ \"Close\": { } }";
  
  return sendPost("Account/<iban>/Close", body);
}

private bool isSuccessful(map[str, str] response) = response["isSuccessful"] == "true" && contains(response["body"], "CommandSuccess");

private void copyState() {
  loc state = |project://rscebl/src/experiments/lightweight/ClosedAccountWithBalance.tebl|;
  loc destination = |project://rebel-core/examples/simple_transaction/<state.file>|;

  writeFile(destination, readFile(state));
}
