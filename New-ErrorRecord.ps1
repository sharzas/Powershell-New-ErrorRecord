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
                
    .PARAMETER InheritInvocationInfo
        If this parameter is specified, and -baseObject is an ErrorRecord, the 
        InvocationInfo.PositionMessage property will used as the -errorId parameter supplied
        to the ErrorRecord constructor.

        The benefit from this is, that the resulting ErrorRecord will have correct position
        information displayed in the FullyQualifiedErrorId part of the ErrorRecord, when 
        re-throwing and error in a function, using $PSCmdlet.ThrowTerminatingError()

        If this parameter is not supplied, the ErrorRecord will show the position of the 
        exception as the line where the function was called, as opposed to the line where the
        exception was thrown. Using this parameter includes both positions, so it will be
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
        You have the following advanced function:
        
        function Test-Function
        {
            [CmdletBinding()]

            Param()

            try {
                Get-Content NonExistingTextFile.txt -ErrorAction Stop
            } catch {
                $ErrorRecord = New-ErrorRecord -BaseObject $_ -exceptionMessage ('Could not read file - 0x{0:X} - {1}' -f $_.Exception.HResult, $_.Exception.Message)

                $PSCmdlet.ThrowTerminatingError($ErrorRecord)                                        
            }
        }

        And call the function: Test-Function

        It will display the following error:

        Test-Function : Could not read file - 0x80131501 - Cannot find path 'C:\Test\NonExistingTextFile.txt' because it does not exist.
        At C:\Test\test.ps1:290 char:1
        + Test-Function
        + ~~~~~~~~~~~~~
            + CategoryInfo          : ObjectNotFound: (C:\Test\NonExis...ingTextFile.txt:String) [Test-Function], ItemNotFoundException
            + FullyQualifiedErrorId : Test-Function


        Note of the error position at line 290, char 1 - this is in fact the line where
        the function is called. To get the exact position of the error included in the
        FullyQualifiedErrorId, you must use the -InheritInvocationInfo parameter. See
        next example...
        
    .EXAMPLE
        You have the following advanced function:
        
        function Test-Function
        {
            [CmdletBinding()]

            Param()

            try {
                Get-Content NonExistingTextFile.txt -ErrorAction Stop
            } catch {
                $ErrorRecord = New-ErrorRecord -BaseObject $_ -InheritInvocationInfo -exceptionMessage ('Could not read file - 0x{0:X} - {1}' -f $_.Exception.HResult, $_.Exception.Message)

                $PSCmdlet.ThrowTerminatingError($ErrorRecord)                                        
            }
        }

        And call the function: Test-Function

        It will display the following error:

        Test-Function : Could not read file - 0x80131501 - Cannot find path 'C:\Test\NonExistingTextFile.txt' because it does not exist.
        At C:\Test\test.ps1:290 char:1
        + Test-Function
        + ~~~~~~~~~~~~~
            + CategoryInfo          : ObjectNotFound: (C:\Test\NonExis...ingTextFile.txt:String) [Test-Function], ItemNotFoundException
            + FullyQualifiedErrorId : At C:\Test\test.ps1:272 char:9
        +         Get-Content NonExistingTextFile.txt -ErrorAction Stop
        +         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~,Test-Function

        Take good note of the included position in FullyQualifiedErrorId - this is the result of
        -InheritInvocationInfo

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
        Version: 1.0

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
        [Switch]$InheritInvocationInfo,
        [Switch]$DontInheritTargetObject,
        [Switch]$DontUpdateInnerException
    )

    Write-Verbose ('New-ErrorRecord(): invoked.')

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

            if ($InheritInvocationInfo) {
                # -InheritInvocationInfo specified: construct information about the original invocation, and store it
                # in errorId of the new record. This is practical if the this errorrecord is made to re-throw via
                # $PSCmdlet.ThrowTerminatingError in a function. If we don't do this, the ErrorRecord will have invocation
                # info, and positional info that points to the line in the script, where the function is called from, 
                # rather than the line where the error occured.
                Write-Verbose ('New-ErrorRecord(): -InheritInvocationInfo specified: Including InvocationInfo.PositionMessage as errorId')

                $errorId =  $baseObject.InvocationInfo.PositionMessage
            } else {
                Write-Verbose ('New-ErrorRecord(): -InheritInvocationInfo NOT specified: InvocationInfo.PositionMessage not included as errorId')
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

                $newException = New-Object ($baseObject.exception.Gettype().Fullname)($exceptionMessage)
            } else {
                # Update InnerException, by adding the exception from the baseObject to the InnerException of the new exception.
                # this preserves the Exception chain.
                Write-Verbose ('New-ErrorRecord(): -DontUpdateInnerException NOT specified: ErrorRecord Exception WILL be added to new Exception.InnerException chain.')

                $newException = New-Object ($baseObject.exception.Gettype().Fullname)($exceptionMessage, $baseObject.exception)
            }            

            # build the ErrorRecord
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
        $Record = New-Object System.Management.Automation.ErrorRecord($newException, $errorId, $errorCategory, $targetObject)
    }

    # return the constructed ErrorRecord
    $Record
} # function New-ErrorRecord