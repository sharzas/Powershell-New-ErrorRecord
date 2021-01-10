function New-ErrorRecord
{
    <#
    .SYNOPSIS
        Build ErrorRecord from scratch, based on Exception, or based on existing ErrorRecord

    .DESCRIPTION
        Build ErrorRecord from scratch, based on Exception, or based on existing ErrorRecord
        
        Especially useful for ErrorRecords used to re-throwing errors in advanced functions
        using $PSCmdlet.ThrowTerminatingError()

        Support for:
        - Build ErrorRecord from scratch, exception or existing ErrorRecord.
        - Inheriting InvocationInfo from existing ErrorRecord
        - Adding Exception from existing ErrorRecord, to InnerException chain
          in of Exception in new ErrorRecord, to preserve full Exception history.
        
    .PARAMETER baseObject
        If supplied, the ErrorRecord will be based on this. It must be either of:

        [System.Exception]
        ==================
        The ErrorRecord will be created based on the other parameters supplied to the function,
        and this Exception is included as is, as the .Exception property.

        [System.Management.Automation.ErrorRecord]
        ==========================================
        The ErrorRecord will be created based on this ErrorRecord. The values of parameters
        that are not supplied to the function, will be derived from this object.

        The exception in this object, will be added to .InnerException chain of the Exception
        created for the new ErrorRecord.

        If specified, InvocationInfo will be inherited from this object, by storing it in
        the FullyQualifiedErrorId property.

    .PARAMETER exceptionType
        If -baseObject has not been supplied, an Exception of this type will be created for
        the ErrorRecord. If this parameter is not supplied, a generic System.Exception will
        be created.

    .PARAMETER exceptionMessage
        Message that is added to the new Exception, attached to the ErrorRecord.
        
        
    .PARAMETER errorId
        This is used to construct the FullyQualifiedErrorId.

        NOTE:
        If -baseObject is an ErrorRecord, and -InheritInvocationInfo is specified as well,
        this parameter will be overridden with the InvocationInfo.PositionMessage property
        of the existing ErrorRecord.
        
    .PARAMETER errorCategory
        Category set in the CategoryInfo of the ErrorRecord. Must be enumerable via the
        [System.Management.Automation.ErrorCategory] enum.

    .PARAMETER targetObject
        Object that was target of the operation. This will be used to display some details
        in the CategoryInfo part of the ErrorRecord - e.g. partial value and Data type of
        the Object (string, int32, etc.).

        Hint: it can be a good idea to include this.

        NOTE: 
        If -baseObject is an ErrorRecord, and this parameter is not supplied, the 
        targetObject of the existing ErrorRecord will be used in the new ErrorRecord as well,
        unless -DontInheritTargetObject is specified.
                
    .PARAMETER DontInheritInvocationInfo
        If this parameter is specified, and -baseObject is an ErrorRecord, the InvocationInfo
        will NOT be inherited in the new ErrorRecord.

        If this parameter isn't specified, and -baseObject is an ErrorRecord, the 
        InvocationInfo.PositionMessage property of the ErrorRecord in baseObject will be 
        appended to the -errorId parameter supplied to the ErrorRecord constructor.

        The benefit from this is, that the resulting ErrorRecord will have correct position
        information displayed in the FullyQualifiedErrorId part of the ErrorRecord, when 
        re-throwing and error in a function, using $PSCmdlet.ThrowTerminatingError()

        If this parameter IS supplied, the ErrorRecord will show the position of the 
        exception as the line where the function was called, as opposed to the line where the
        exception was thrown. Not using this parameter includes both positions, so it will be
        possible to see both where the function was called, and where the Exception was thrown.

    .PARAMETER DontInheritTargetObject
        If specified, and -baseObject is an ErrorRecord, and -targetObject isn't specified
        either, the value of targetObject will be set to $null, to prevent inheritance of
        this value from the existing ErrorRecord.

    .PARAMETER DontUpdateInnerException
        If specified, and -baseObject is an ErrorRecord, the exception created for the new
        ErrorRecord, will not have its .InnerException property chain updated with the
        the Exception from the ErrorRecord in baseObject, and thus the Exception history
        will be reset.

    .EXAMPLE
        You have the following advanced functions:
        
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
                $PSCmdlet.ThrowTerminatingError((New-ErrorRecord -baseObject $_ -DontInheritInvocationInfo))
            }
        } # function Test-LevelOne

        And call the function: Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-LevelOne"

        It will display the following error:

        PS C:\Test> .\Test.ps1
        Test-LevelOne : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
        At C:\Test\Test.ps1:28 char:1
        + Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-Le ...
        + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            + CategoryInfo          : ObjectNotFound: (C:\Test\NonExistingFile.txt:String) [Test-LevelOne], ItemNotFoundException
            + FullyQualifiedErrorId : errorId not specified,Test-LevelOne

        Note of the error position at line 28, char 1 - this is in fact the line where
        the function Test-LevelOne is called. To get the exact position of the error included 
        in the FullyQualifiedErrorId, do not use the -DontInheritInvocationInfo parameter in
        Test-LevelOne when calling New-ErrorRecord. See next example...
        
    .EXAMPLE
        You have the following advanced function:
        
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

        And call the function: Test-LevelOne -TestLevelOneParameter "This is a parameter for Test-LevelOne"

        It will display the following error:

        PS C:\Test> .\Test.ps1
        Test-LevelOne : Cannot find path 'C:\Test\NonExistingFile.txt' because it does not exist.
        At C:\Test\Test.ps1:28 char:1
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

        Take good note of the position for all exceptions in the chain, included
        in FullyQualifiedErrorId - this is the result of -DontInheritInvocationInfo not being used.

    .EXAMPLE
        $TestString = "this is a string"
        $ErrorRecord = New-ErrorRecord -exceptionType "System.Exception" -exceptionMessage "This is an Exception" -errorId "This is a test error record" -errorCategory "ReadError" -targetObject $TestString

        throw $ErrorRecord

        Will throw the following error:

        This is an Exception
        At C:\Test\test.ps1:290 char:1
        +     throw $ErrorRecord
        +     ~~~~~~~~~~~~~~~~~~
            + CategoryInfo          : ReadError: (this is a string:String) [], Exception
            + FullyQualifiedErrorId : This is a test error record        

    .EXAMPLE
        You may also @Splay parameters via HashTable for better readability:

        $TestString = "this is a string value"

        $Param = @{
            exceptionType = "System.Exception"
            exceptionMessage = "This is an Exception generated with @Splatted parameters"
            errorId = "This is a test error record"
            errorCategory = "ReadError" 
            targetObject = $TestString
        }

        $ErrorRecord = New-ErrorRecord @Param

        throw $ErrorRecord

        Will throw the following error:

        This is an Exception generated with @Splatted parameters
        At C:\Test\test.ps1:290 char:1
        +     throw $ErrorRecord
        +     ~~~~~~~~~~~~~~~~~~
            + CategoryInfo          : ReadError: (this is a string value:String) [], Exception
            + FullyQualifiedErrorId : This is a test error record


    .OUTPUTS
        An ErrorRecord object.

    .NOTES
        Author.: Kenneth Nielsen (sharzas @ GitHub.com)
        Version: 1.1

    .LINK
        https://github.com/sharzas/Powershell-Get-StorCLIStatus
    #>

    [CmdletBinding()]

    Param (
        [System.Object]$baseObject,
        [System.String]$exceptionType = "System.Exception",
        [System.string]$exceptionMessage = "exceptionMessage not specified",
        [System.string]$errorId = "errorId not specified",
        [System.Management.Automation.ErrorCategory]$errorCategory = "NotSpecified",
        [System.Object]$targetObject = $null,
        [Switch]$DontInheritInvocationInfo,
        [Switch]$DontInheritTargetObject,
        [Switch]$DontUpdateInnerException
    )

    Write-Verbose ('New-ErrorRecord(): invoked.')



    function Split-WordWrap
    {
        <#
        .SYNOPSIS
            Word wrap a text block at specified width.

        .DESCRIPTION
            Word wrap a text block at specified width.
            
        .PARAMETER Text
            Text block to perform Word Wrap on.

        .PARAMETER Width
            Maximum width of each line. Lines will word wrapped so as to not exceed this line
            length.
            
            If any words in the text block is longer than the maximum width of a line, they
            will be split.

        .PARAMETER SplitLongWordCharacter
            Character that will be inserted at the end of each line, if it becomes neccessary
            to split a very long word.
            
        .PARAMETER NewLineCharacter
            This is the character that will be used for line feeds. Because of various
            possible scenarious this parameter has been included.

            Default is "`n" (LF), but some may prefer "`r`n" (CRLF)

            Just be aware that "`r`n" will make Powershell native code interpret an extra
            empty line, for each line... on the other hand, applications that expect "`r`n"
            will need that.

        .EXAMPLE
            Split-WordWrap -Line "this is a long line that needs some wrapping" -Width 15

            Will output the string value:

            this is a long
            line that needs
            some wrapping
            
        .EXAMPLE
            Split-WordWrap -Line "this long line contains SomeVeryLongWordsThatNeedSplitting and SomeOtherVeryLongWords" -Width 15

            Will output the string value:

            this long line
            contains SomeV-
            eryLongWordsTh-
            atNeedSplitting
            and SomeOtherV-
            eryLongWords

        .OUTPUTS
            String containing the input text block, in word wrapped format, according to
            -Width

        .NOTES
            Author.: Kenneth Nielsen (sharzas @ GitHub.com)
            Version: 1.0
        #>

        [CmdletBinding()]
        Param (
            [String]$Text,
            $Width = $null,
            $SplitLongWordCharacter = "-",
            $NewLineCharacter = "`n"
        )
    
        Write-Verbose ('Split-WordWrap(): invoked')

        if ($null -eq $Width) {
            # if Width not supplied, or is null, then simply return as is.
            # should let it work under ISE as well, if calling using some
            # (Get-Host).UI.RawUI values.
            return $Text
        }

        # replace single newline characters to CRLF
        $Text = $Text.Replace("`r`n","`n")
    
        # split line into separate lines by CRLF if any is present.
        $Lines = $Text.Split("`n")
    
        $NewContent = foreach ($Line in $Lines) {
            $Words = $Line.Split(" ")
    
            # for each line, start with a blank line variable. We'll add to this one until we reach the specified
            # width, at which point we will wrap to next line.
            $NewLine = ""
    
            foreach ($Word in $Words) {
                $Skip = $false
    
                Write-Verbose ('Split-WordWrap(): ("{0}" + "{1}").Length -gt "{2}" = "{3}"' -f $NewLine, ('{0}' -f $Word), $Width, $(($NewLine + $Word).Length -gt $Width))
    
                if (($NewLine + ('{0}' -f $Word)).Length -gt $Width) {
                    # Current line + addition of the next word, will exceed the specified width, so we need to wrap here
                    if ($Word.Length -gt $Width) {
                        # The next word is wider than the specified width, so we need to split that word in order to
                        # be able to wrap it.
                        Write-Verbose ('Word is wider than width, need to split in order to wrap: "{0}"' -f $Word)
    
                        $TooLongWord = $Newline + $Word
    
                        Do {
                            $SplittedWord = ('{0}{1}' -f $TooLongWord.Substring(0,($Width-1)), $SplitLongWordCharacter)
                            $SplittedWord
                            Write-Verbose ('Split-WordWrap(): $SplittedWord is now = "{0}"' -f $SplittedWord)
    
                            $TooLongWord = $TooLongWord.Substring($Width-1)
                            Write-Verbose ('Split-WordWrap(): $TooLongWord.Substring({0}) = "{1}"' -f ($Width-1),$TooLongWord)
                        }
                        Until ($TooLongWord.Length -le $Width)
    
                        $NewLine = ('{0} ' -f $TooLongWord)
    
                        # we need to skip adding this word to the current line, as we've just done that.
                        $Skip = $true
                    } else {
                        # The next word is narrower than specified width, so we can wrap simply by completing current
                        # line, and adding this word as the beginning of a new line.
    
                        # output current line
                        Write-Verbose ('Split-WordWrap(): New Line "{0}"' -f $NewLine.Trim())
                        $NewLine.Trim()
    
                        # reset line, in preparation for adding the next word as a new line.
                        $NewLine = ""    
                    }
                }
    
                if (!$Skip) {
                    # skip has not been specified, so add current word to current line
                    $NewLine += ('{0} ' -f $Word)
                }
                
            }
            Write-Verbose ('Split-WordWrap(): New Line "{0}"' -f $NewLine.Trim())
            $NewLine.Trim()
        }    
    
        Write-Verbose ('Split-WordWrap(): Joining {0} lines to return' -f $NewContent.Count)

        $NewContent = $NewContent -Join $NewLineCharacter
        return $NewContent
    } # function Split-WordWrap



    $Record = $null

    if ($PSBoundParameters.ContainsKey("baseObject")) {
        # base object was supplied - this must be either [System.Exception] or [System.Management.Automation.ErrorRecord]
        if ($baseObject -is [System.Exception]) {
            # exception
            # an existing exception was specified, so use that to create the errorrecord.
            Write-Verbose ('New-ErrorRecord(): -baseObject is [System.Exception]: build ErrorRecord using this Exception.')

            $Record = New-Object System.Management.Automation.ErrorRecord($baseObject, $errorId, $errorCategory, $targetObject)

        } elseif ($baseObject -is [System.Management.Automation.ErrorRecord]) {
            # errorrecord
            # an existing ErrorRecord was specified, so use that to create the new errorrecord.
            Write-Verbose ('New-ErrorRecord(): -baseObject is [System.Management.Automation.ErrorRecord]: build ErrorRecord based on this.')

            if (!$DontInheritInvocationInfo) {
                # -DontInheritInvocationInfo NOT specified: construct information about the original invocation, and store it
                # in errorId of the new record. This is practical if the this errorrecord is made to re-throw via
                # $PSCmdlet.ThrowTerminatingError in a function. If we don't do this, the ErrorRecord will have invocation
                # info, and positional info that points to the line in the script, where the function is called from, 
                # rather than the line where the error occured.
                Write-Verbose ('New-ErrorRecord(): -DontInheritInvocationInfo NOT specified: Including InvocationInfo.PositionMessage as errorId')

                # Set some indentation values
                $Indentation = " "*2
                $DataIndentation = 26

                $PositionMessage = $baseObject.InvocationInfo.PositionMessage.Split("`n") -replace "^\+\s+", ""


                if ($PositionMessage.Count -gt 1) {
                    $PositionMessage[1..$PositionMessage.GetUpperBound(0)]|ForEach-Object {
                        $_ = ('+{0}{0}{1}' -f $Indendation,$_)
                    }
                }

                $PositionMessage = $PositionMessage -join "`n"

                # Base value of errorId
                $errorIdBase = @'
{0}
 
Source.CategoryInfo     : "{2}"
Source.Exception.Message: "{3}"
Source.Exception.Line   : {4}
Source.Exception.Thrown : {5}
 
--- {6} : {7}
'@
                
                if (!$PSBoundParameters.ContainsKey("errorId")) {
                    # -errorId not specified, so merge "NotSpecified" string with FullyQualifiedErrorId chain
                    # of existing ErrorRecord.
                    #
                    # We will do some word wrapping here as well, with respect to the current size of the
                    # Powershell Host Window, to avoid some indentation done by Powershell when displaying
                    # ErrorRecords, containing lines that doesn't fit the Console window.
                    #
                    Write-Verbose ('New-ErrorRecord(): -errorId NOT specified: constructing by merging "NotSpecified" string with FullyQualifiedErrorId chain.')

                    $errorId = $errorIdBase -f `
                        "NotSpecified", `
                        $Indentation, `
                        (Split-WordWrap -Text $baseObject.CategoryInfo.ToString() -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $baseObject.Exception.Message -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $baseObject.InvocationInfo.Line.Trim() -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $PositionMessage -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}+{1}" -f (" "*$DataIndentation), $Indentation)), `
                        $baseObject.InvocationInfo.InvocationName, `
                        $baseObject.FullyQualifiedErrorId
                } else {
                    # -errorId specified, so merge with existing ErrorRecords InvocationInfo and a NewLine.
                    #
                    # We will do some word wrapping here as well, with respect to the current size of the
                    # Powershell Host Window, to avoid some indentation done by Powershell when displaying
                    # ErrorRecords, containing lines that doesn't fit the Console window.
                    #
                    Write-Verbose ('New-ErrorRecord(): -errorId specified: constructing by merging -errorId with FullyQualifiedErrorId chain.')

                    $errorId = $errorIdBase -f `
                        $errorId, `
                        $Indentation, `
                        (Split-WordWrap -Text $baseObject.CategoryInfo.ToString() -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $baseObject.Exception.Message -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $baseObject.InvocationInfo.Line.Trim() -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}" -f (" "*$DataIndentation))), `
                        (Split-WordWrap -Text $PositionMessage -Width ((Get-Host).UI.RawUI.WindowSize.Width - ($DataIndentation+8))).Replace("`n",("`n{0}+{1}" -f (" "*$DataIndentation), $Indentation)), `
                        $baseObject.InvocationInfo.InvocationName, `
                        $baseObject.FullyQualifiedErrorId
                }

            } else {
                Write-Verbose ('New-ErrorRecord(): -DontInheritInvocationInfo specified: InvocationInfo.PositionMessage not included as errorId')
            }

            if (!$PSBoundParameters.ContainsKey("errorCategory")) {
                # errorCategory wasn't specified, so use the one from the baseObject
                Write-Verbose ('New-ErrorRecord(): -errorCategory NOT specified: using info from -baseObject ErrorRecord')

                $errorCategory = $baseObject.CategoryInfo.Category
            } else {
                Write-Verbose ('New-ErrorRecord(): -errorCategory specified: using info from -errorCategory')
            }

            Write-Verbose ('New-ErrorRecord(): errorCategory: "{0}"' -f $errorCategory)

            if (!$PSBoundParameters.ContainsKey("exceptionMessage")) {
                # exceptionMessage wasn't specified, so use the one from the exception in the baseObject
                Write-Verbose ('New-ErrorRecord(): -exceptionMessage NOT specified: using info from -baseObject ErrorRecord')

                $exceptionMessage = $baseObject.exception.message
            }

            Write-Verbose ('New-ErrorRecord(): exceptionMessage: "{0}"' -f $errorCategory)

            if (!$PSBoundParameters.ContainsKey("targetObject")) {
                # targetObject wasn't specified

                if ($DontInheritTargetObject) {
                    # -DontInheritTargetObject specified, so set to null
                    Write-Verbose ('New-ErrorRecord(): -targetObject NOT specified, but -DontInheritTargetObject was: setting $null value')
                } else {
                    # Use the one from the baseObject
                    $targetObject = $baseObject.TargetObject

                    Write-Verbose ('New-ErrorRecord(): -targetObject NOT specified: using info from -baseObject ErrorRecord')
                }
            } else {
                Write-Verbose ('New-ErrorRecord(): -targetObject specified: added to ErrorRecord')
            }

            if ($DontUpdateInnerException) {
                # Build new exception without adding existing exception from baseObject to InnerException
                Write-Verbose ('New-ErrorRecord(): -DontUpdateInnerException specified: ErrorRecord Exception will not be added to new Exception.InnerException chain.')

                if ($PSBoundParameters.ContainsKey("exceptionType")) {
                    # -exceptionType specified, use that for the new exception
                    Write-Verbose ('New-ErrorRecord(): -exceptionType specified: creating Exception of type "{0}"' -f $exceptionType)
                    
                    $newException = New-Object $exceptionType($exceptionMessage)
                } else {
                    # -exceptionType NOT specified, use baseObject.exception type for the new exception
                    Write-Verbose ('New-ErrorRecord(): -exceptionType NOT specified: creating Exception of type "{0}"' -f $baseObject.exception.Gettype().Fullname)

                    $newException = New-Object ($baseObject.exception.Gettype().Fullname)($exceptionMessage)
                }
            } else {
                # Update InnerException, by adding the exception from the baseObject to the InnerException of the new exception.
                # this preserves the Exception chain.
                Write-Verbose ('New-ErrorRecord(): -DontUpdateInnerException NOT specified: ErrorRecord Exception WILL be added to new Exception.InnerException chain.')

                if ($PSBoundParameters.ContainsKey("exceptionType")) {
                    # -exceptionType specified, use that for the new exception
                    Write-Verbose ('New-ErrorRecord(): -exceptionType specified: creating Exception of type "{0}"' -f $exceptionType)

                    $newException = New-Object $exceptionType($exceptionMessage, $baseObject.exception)
                } else {
                    # -exceptionType NOT specified, use baseObject.exception type for the new exception
                    Write-Verbose ('New-ErrorRecord(): -exceptionType NOT specified: creating Exception of type "{0}"' -f $baseObject.exception.Gettype().Fullname)

                    $newException = New-Object ($baseObject.exception.Gettype().Fullname)($exceptionMessage, $baseObject.exception)
                }
            }            

            # build the ErrorRecord
    
            Write-Verbose ('New-ErrorRecord(): $newException  = {0}' -f $newException.gettype().fullname)
            Write-Verbose ('New-ErrorRecord(): $errorId       = {0}' -f $errorId.gettype().fullname)
            Write-Verbose ('New-ErrorRecord(): $errorCategory = {0}' -f $errorCategory.gettype().fullname)
            Write-Verbose ('New-ErrorRecord(): $targetObject  = {0}' -f $(if ($null -eq $targetObject) {"null"} else {$targetObject.gettype().fullname}))

            $Record = New-Object System.Management.Automation.ErrorRecord($newException, $errorId, $errorCategory, $targetObject)

        } else {
            # unsupported type - prepare to create the exception ourselves.
            Write-Verbose ('New-ErrorRecord(): -baseObject is an invalid type [{0}]: will be ignored. Building ErrorRecord using parameters if possible.' -f $baseObject.GetType().FullName)
        }

    }

    if ($null -eq $Record) {
        # baseObject not specified, or was invalid type, so create ErrorRecord by using parameters
        Write-Verbose ('New-ErrorRecord(): Building ErrorRecord using parameters.')

        # output any unspecified parameters verbosely
        @("exceptionMessage","errorId","errorCategory","targetObject")|ForEach-Object {
            if (!$PSBoundParameters.ContainsKey($_)) {
                # Parameter wasn't specified, use default value.
                Write-Verbose ('New-ErrorRecord(): -{0} NOT specified: using default value' -f $_)
            }
        }

        # create a new exception to embed in the ErrorRecord.
        $newException = New-Object $exceptionType($exceptionMessage)
    
        # Build record

        Write-Verbose ('New-ErrorRecord(): $newException  = {0}' -f $newException.gettype().fullname)
        Write-Verbose ('New-ErrorRecord(): $errorId       = {0}' -f $errorId.gettype().fullname)
        Write-Verbose ('New-ErrorRecord(): $errorCategory = {0}' -f $errorCategory.gettype().fullname)
        Write-Verbose ('New-ErrorRecord(): $targetObject  = {0}' -f $(if ($null -eq $targetObject) {"null"} else {$targetObject.gettype().fullname}))

        $Record = New-Object System.Management.Automation.ErrorRecord($newException, $errorId, $errorCategory, $targetObject)
    }

    # return the constructed ErrorRecord
    $Record

} # function New-ErrorRecord