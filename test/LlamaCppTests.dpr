program LlamaCppTests;
{

  Delphi DUnit Test Project
  -------------------------
  Console runner for the llama.cpp binding tests. It uses a custom
  ITestListener that prints a flushed marker for every test event, so that a
  hanging test can be pinpointed in redirected output even when llama.cpp's own
  log spam floods the stream. The process exit code reflects the test outcome
  (0 = all green), which keeps the dtest.cmd contract honest.

  The stock DUnitTestRunner is intentionally not used: its console path waits
  for keyboard input on exit and its GUI path pulls in the VCL, both of which
  stall an automated, redirected run.

}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TestFramework,
  HighLevelAPI in 'HighLevelAPI.pas',
  ChatFormatters in 'ChatFormatters.pas',
  Utils in 'Utils.pas';

{$R *.RES}

type
  // Emits a flushed marker for every test event to locate hangs in redirected output.
  TProgressListener = class(TInterfacedObject, ITestListener)
  public
    procedure AddSuccess(ATest: ITest);
    procedure AddError(AError: TTestFailure);
    procedure AddFailure(AFailure: TTestFailure);
    procedure StartTest(ATest: ITest);
    procedure EndTest(ATest: ITest);
    procedure TestingStarts();
    procedure TestingEnds(ATestResult: TTestResult);
    function ShouldRunTest(ATest: ITest): boolean;
    procedure Status(ATest: ITest; const AMsg: string);
  end;

// Writes one line to stdout and flushes immediately so markers survive buffering.
procedure WriteFlushed(const AText: string);
begin
  WriteLn(AText);
  Flush(Output);
end;

// Success is reported via EndTest; keep per-test output compact.
procedure TProgressListener.AddSuccess(ATest: ITest);
begin
end;

// Reports an unexpected exception (error) in a test.
procedure TProgressListener.AddError(AError: TTestFailure);
begin
  WriteFlushed('### ERROR in ' + AError.FailedTest.Name + ': ' +
    AError.ThrownExceptionMessage);
end;

// Reports a failed assertion (failure) in a test.
procedure TProgressListener.AddFailure(AFailure: TTestFailure);
begin
  WriteFlushed('### FAIL in ' + AFailure.FailedTest.Name + ': ' +
    AFailure.ThrownExceptionMessage);
end;

// Marks the start of a single test or test suite.
procedure TProgressListener.StartTest(ATest: ITest);
begin
  WriteFlushed('### START ' + ATest.Name);
end;

// Marks the end of a single test or test suite.
procedure TProgressListener.EndTest(ATest: ITest);
begin
  WriteFlushed('### END   ' + ATest.Name);
end;

// Marks the beginning of the whole run.
procedure TProgressListener.TestingStarts();
begin
  WriteFlushed('### TESTING STARTS');
end;

// Marks the end of the whole run and prints the summary counts.
procedure TProgressListener.TestingEnds(ATestResult: TTestResult);
begin
  WriteFlushed(Format('### TESTING ENDS: %d run, %d failures, %d errors',
    [ATestResult.RunCount, ATestResult.FailureCount, ATestResult.ErrorCount]));
end;

// Runs every registered test; no filtering.
function TProgressListener.ShouldRunTest(ATest: ITest): boolean;
begin
  Result := True;
end;

// Forwards a status message emitted by a running test.
procedure TProgressListener.Status(ATest: ITest; const AMsg: string);
begin
  WriteFlushed('### STATUS ' + ATest.Name + ': ' + AMsg);
end;

var
  TestResult: TTestResult;
begin
  TestResult := TestFramework.RunTest(RegisteredTests, [TProgressListener.Create]);
  try
    WriteFlushed(Format('### TESTS DONE: %d run, %d failures, %d errors',
      [TestResult.RunCount, TestResult.FailureCount, TestResult.ErrorCount]));
    // Non-zero exit code on any failure or error so dtest.cmd reflects the result.
    if (TestResult.FailureCount > 0) or (TestResult.ErrorCount > 0) then
      ExitCode := 1;
  finally
    TestResult.Free;
  end;
  WriteFlushed('### BEFORE FINALIZATION (unit finalization / DLL unload follows)');
end.
