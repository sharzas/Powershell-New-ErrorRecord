Powershell Function "New-ErrorRecord"

Author.: Kenneth Nielsen (sharzas @ GitHub)
Version: See function notes.

Description
===========
Build ErrorRecord from scratch, based on Exception, or based on existing ErrorRecord
        
Especially useful for ErrorRecords used to re-throwing errors in advanced functions
using $PSCmdlet.ThrowTerminatingError()

Support for:
 - Build ErrorRecord from scratch, exception or existing ErrorRecord.
 - Inheriting InvocationInfo and Exception chain from existing ErrorRecord
   - Adds Exceptions to InnerException
 - Adding Exception from existing ErrorRecord, to InnerException chain
   in of Exception in new ErrorRecord, to preserve full Exception history.
 - Word wrap built in, so that the error record is designed with respect for
   the Powershell console width. This avoids some nasty indentation Powershell
   applies, when displaying an ErrorRecord where some of the lines needs to
   wrap around to fit the console... makes it look quite ugly, but the built
   in word wrapper should take care of that.


Background and purpose
======================
Some may correctly claim that most of what this function does, is already built into
Powershell. However with a few caveats, and then some more.

I made this function, to help myself get more detailed information about errors inside
functions. Powershell is pretty good at building ErrorRecords, which contains some
usefull information, however when it comes to errors happening inside functions, they
could contain more information, and this is where this function comes into play, along
with $PSCmdlet.ThrowTerminatingError().

The main thing I wanted to accomplish, was to preserve an Exception/ErrorRecord chain,
in order to show a stack-like history of events causing the error. In my opinion I
succeeded nicely, and if you use the New-ErrorRecord function appropriately, you will
get very detailed information about your error trail.

A demonstration is probably in place, to illustrate both the caveats mentioned, and
the benefits from both using $PSCmdlet.ThrowTerminatingError() and New-ErrorRecord.

Consider the script below (New-ErrorRecord left out to preserve space):

========== [SNIP] ==========
[CmdletBinding()]
Param()

function Test-LevelTwo
{
    [CmdletBinding()]
    Param ($TestLevelTwoParameter)

    try {
        Get-Content NonExistingFile.txt -ErrorAction Stop
    } catch {
        Throw $_
    }
} # function Test-LevelTwo

function Test-LevelOne
{
    [CmdletBinding()]
    Param ($TestLevelOneParameter)

    try {
        Test-LevelTwo -TestLevelTwoParameter "This is a parameter for Test-LevelTwo"
    } catch {
        Throw $_
    }
} # function Test-LevelOne

Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-LevelOne"
========== [SNAP] ==========

If you run this - which doesn't use neither $PSCmdlet.ThrowTerminatingError() or
New-ErrorRecord, you will get error output like below:
=======================
PS C:\Test> .\Test.ps1
Get-Content : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
At C:\Test\Test.ps1:7 char:9
+         Get-Content NonExistingFile.txt -ErrorAction Stop
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Get-Content], ItemNotFoundException
    + FullyQualifiedErrorId : PathNotFound,Microsoft.PowerShell.Commands.GetContentCommand
=======================

This will tell you exactly where the error originated, and not much else. In many
cases this would be enough, however you would need to construct or know the context
in which the functions was called and used, to be able to track down the error.
This can be troublesome, especially if you have a set of functions being used
heavily throughout your script - e.g. like a logging or console output function.

So - imagine we decide to use $PSCmdlet.ThrowTerminatingError() instead. The
purpose of that method, is to keep the error local to the function context, and it
will provide some useful information about where the error happened.

========== [SNIP] ==========
[CmdletBinding()]
Param()

function Test-LevelTwo
{
    [CmdletBinding()]
    Param ($TestLevelTwoParameter)

    try {
        Get-Content NonExistingFile.txt -ErrorAction Stop
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
} # function Test-LevelTwo

function Test-LevelOne
{
    [CmdletBinding()]
    Param ($TestLevelOneParameter)

    try {
        Test-LevelTwo -TestLevelTwoParameter "This is a parameter for Test-LevelTwo"
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
} # function Test-LevelOne

Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-LevelOne"
========== [SNAP] ==========

Now you get below output:
=========================
PS C:\Test> .\Test.ps1
Test-LevelOne : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
At C:\Test\Test.ps1:28 char:1
+ Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-Le ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Test-LevelOne], ItemNotFoundException
    + FullyQualifiedErrorId : PathNotFound,Test-LevelOne
=========================

This will tell you what kind of exception you ran into, what the target of the operation,
along with the name of the function in which the error happened. You also get some other
useful information, like part of the command used to call the function. This is great - 
except:

- The error actually happened in the second function being called (Test-FunctionLevelTwo)
  * This is of course only an issue if you have a function, that calls another function,
    but it happens quite often, so its an annoyance.

- The position indication of the error, points to the initial line where the function
  call is being made, and not the line where the error itself happened.


So... lets look at pairing $PSCmdlet.ThrowTerminatingError() with New-ErrorRecord instead:


========== [SNIP] ==========
[CmdletBinding()]
Param()

function Test-LevelTwo
{
    [CmdletBinding()]
    Param ($TestLevelTwoParameter)

    try {
        Get-Content NonExistingFile.txt -ErrorAction Stop
    } catch {
        $PSCmdlet.ThrowTerminatingError((New-ErrorRecord -baseObject $_))
    }
} # function Test-LevelTwo

function Test-LevelOne
{
    [CmdletBinding()]
    Param ($TestLevelOneParameter)

    try {
        Test-LevelTwo -TestLevelTwoParameter "This is a parameter for Test-LevelTwo"
    } catch {
        $PSCmdlet.ThrowTerminatingError((New-ErrorRecord -baseObject $_))
    }
} # function Test-LevelOne

Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-LevelOne"
========== [SNAP] ==========

Now you get below output:
=========================
PS C:\Test> .\Test.ps1
Test-LevelOne : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
At C:\Test\Test.ps1:661 char:1
+ Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-Le ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Test-LevelOne], ItemNotFoundException
    + FullyQualifiedErrorId : NotSpecified

Source.CategoryInfo     : "ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Test-LevelTwo], ItemNotFoundException"
Source.Exception.Message: "Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist."
Source.Exception.Line   : Test-LevelTwo -TestLevelTwoParameter "This is a parameter for Test-LevelTwo"
Source.Exception.Thrown : At C:\Test\Test.ps1:22 char:9
                          +  Test-LevelTwo -TestLevelTwoParameter "This is a parameter for ...
                          +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--- Test-LevelTwo : NotSpecified

Source.CategoryInfo     : "ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Get-Content], ItemNotFoundException"
Source.Exception.Message: "Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist."
Source.Exception.Line   : Get-Content NonExistingFile.txt -ErrorAction Stop
Source.Exception.Thrown : At C:\Test\Test.ps1:10 char:9
                          +  Get-Content NonExistingFile.txt -ErrorAction Stop
                          +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--- Get-Content : PathNotFound,Microsoft.PowerShell.Commands.GetContentCommand,Test-LevelTwo,Test-LevelOne
=========================
You now get full Exception/ErrorRecord history - you will notice that we have both, the exact
location in the script where top level error happened, as well as each individual locations, 
where an exception was triggered, and what command was used for the function call/command/cmdlet.

Exception chain are in the ErrorRecord.Exception.InnerException properties - we can see that by perusing
the Exception.InnerException part of the $Error variable returned from the above error:

=========================
PS C:\Test> $e = $Error[0].Exception.InnerException;While ($null -ne $e) {$e|Select {$_.Message},{$_.HResult},{$_.ItemName},{$_.Data},{$_.Source},{$_.StackTrace},{$_.WasThrownFromThrowStatement};$e = $e.InnerException}


$_.Message                     : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
$_.HResult                     : -2146233087
$_.ItemName                    :
$_.Data                        : {}
$_.Source                      : System.Management.Automation
$_.StackTrace                  :    at System.Management.Automation.MshCommandRuntime.ThrowTerminatingError(ErrorRecord errorRecord)
$_.WasThrownFromThrowStatement : False

$_.Message                     : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
$_.HResult                     : -2146233087
$_.ItemName                    : C:\Test\NonExistingFile.txt
$_.Data                        : {}
$_.Source                      : System.Management.Automation
$_.StackTrace                  :    at System.Management.Automation.LocationGlobber.ExpandMshGlobPath(String path, Boolean allowNonexistingPaths, PSDriveInfo drive, ContainerCmdletProvider provider, CmdletProviderContext context)
                                    at System.Management.Automation.LocationGlobber.ResolveDriveQualifiedPath(String path, CmdletProviderContext context, Boolean allowNonexistingPaths, CmdletProvider& providerInstance)
                                    at System.Management.Automation.LocationGlobber.GetGlobbedMonadPathsFromMonadPath(String path, Boolean allowNonexistingPaths, CmdletProviderContext context, CmdletProvider& providerInstance)
                                    at Microsoft.PowerShell.Commands.ContentCommandBase.ResolvePaths(String[] pathsToResolve, Boolean allowNonexistingPaths, Boolean allowEmptyResult, CmdletProviderContext currentCommandContext)
$_.WasThrownFromThrowStatement : False
=========================


So bottom line - I personally like this way of error reporting... yes you can backtrack
from normal ErrorRecords, and looking at exceptions, however this makes it easier -
in my opinion anyway.