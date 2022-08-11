function Get-SharedAttributeEntities 


{   # 20220810 by Apostolis Drakakis
    <# 
    .SYNOPSIS
    Use this function to filter between different entities that use the same attribute and find which one uses it.
    Common use case: "Where the @#$% is the SMTP address being used in my tenant?"
    .PARAMETER ToList
    String Array with CMDlets to be used.
    e.g. "Get-Mailbox","Get-UnifiedGroup" etc
    .PARAMETER ToSearch
    Wildcard of this string will be used to filter through the cmdlets
    
    .PARAMETER CommonAttribute
    String of the attribute you are searching for. 
    Default is "PrimarySMTPAddress"
    
    .EXAMPLE
    Get-SharedAttributeEntities -ToList "Get-Mailbox","Get-MailUser" -ToSearch "Accounts" -CommonAttribute "PrimarySMTPAddress"
    
    .NOTES
    #TODO: Cleanup nested function get-objectbasedoncommonattribute 
    #>
    Param( [Parameter(Mandatory=$true, ValueFromPipeline=$true)] 
            [String[]] $ToList, 
            [String] $ToSearch, 
            [String] $CommonAttribute = "PrimarySmtpAddress")
    cls
    
    #Setup HashTable that will be returned
    $inList  = @{
        Choices = [System.Collections.Generic.List[System.Object]]@()
        ToPick = [System.Collections.Generic.List[System.Object]]@()
        Picked = [System.Collections.Generic.List[System.Object]]@()
        UnpickedMenu = [String]""
        Ansi = [String[]] "`e[30;32m", "`e[30;31m", "`e[0m"
        ToRun = [System.Collections.Generic.List[System.Object]]@() 
        
    }
    
    foreach ($piece in $ToList){
        [String]$InList.UnpickedMenu += ("$($inList.Ansi[0])$piece$($InList.Ansi[-1]) `r`n")
    }

    #Add HashTable elements with self-reference.
    $inList += @{
        
        PickedMenu = [String] "$($inList.Ansi[0])Options Selected to Run:$($InList.Ansi[-1])"
        Title = [String] "$($inList.Ansi[1])Pick your Poison$($InList.Ansi[-1])"
        
        
    }
    $inList.Caption = $inList.UnpickedMenu + "`r`n" + $inList.PickedMenu
    [System.Collections.Generic.List[System.Object]]$inList.ToPick = $inList.UnpickedMenu.Split("`r`n")

    for ($i=0; $i -lt $ToList.Count; $i++ ){
        #Setup Choices to be added to Hashtable
        $tempChoice =  [System.Management.Automation.Host.ChoiceDescription]::new("&$($i+1).$($ToList[$i])")
        $tempChoice.HelpMessage = "This is help for $($ToList[$i]) Command "
        $tempInvoke = "Write-Host $($ToList[$i]) Invoked"
        $tempSB = [Scriptblock]::Create($tempInvoke)
        $tempChoice | Add-Member -MemberType ScriptMethod -Name "Method" -Value $tempSB -force
        $inList.Choices.Add($tempChoice) 
    }

    #Setup Default Choices - Quit & Proceed
    $q = [System.Management.Automation.Host.ChoiceDescription]::new("&Quit")
    $q.HelpMessage = "Quit"
    $q | Add-Member -MemberType ScriptMethod -Name "Method" -Value {Write-Host "Quitting." -ForegroundColor Green ; Return} -force
    $p = [System.Management.Automation.Host.ChoiceDescription]::new("&Proceed")
    $p.HelpMessage = "Proceed"
    $p | Add-Member -MemberType ScriptMethod -Name "Method" -Value {Write-Host "Proceeding" -ForegroundColor Green ; Return} -force
    $inList.Choices.Add($p)
    $inList.Choices.Add($q)

    do {
        $r = $host.UI.PromptForChoice($InList.Title,$InList.Caption,$InList.Choices.ToArray(),0)
        $inList.Picked.Add($inList.Choices[$r])
        $inList.Choices.RemoveAt($r)
        $inList.PickedMenu += ("`r`n" + $inList.ToPick[$r])
        $inList.ToPick.RemoveAt($r)
        $inList.UnpickedMenu = $inList.ToPick -join "`r`n"
        $inList.Caption = $inList.UnpickedMenu + "`r`n" + $inList.PickedMenu
        cls
    }
    until($inList.Picked.Contains($q) -or $inList.Picked.Contains($p))


    if($inList.PickedMenu.Contains($q)){Break}

    #Return ,$inList

    function global:Get-ObjectBasedOnCommonAttribute{
        $search = "*$ToSearch*"
        
        #This can get a lot cleaner if you implement a "clean" String Array to carry the CMDlets. 
        #Here I just "cleaned-up" the already carrying Array in order to make it work.
        #Useful-hair-pulling data: The Call operator is pretty sensitive. Cannot work with ANSI parsed strings or any kind of white space.
        [System.Collections.ArrayList]$queries = $inList.PickedMenu.Split("`r`n")
        $queries.removeat(0)
        $queries = $queries | where {$_ -ne ""}

        $queries = $queries | ForEach-Object { $_ -replace '\x1b\[[0-9;]*m','' }
        $queries = $queries | ForEach-Object{$_ -replace ".$"}
        $found
        
        Write-Host "Executing $($inList.PickedMenu)"
        foreach($query in $queries){
        Write-Host "Searching with CMDlet $query"    
        $smtp = & $query | where {$_.$CommonAttribute -like $search}        
        $found += $smtp
        }
                
        if($found) {return $found | ft Name, RecipientType, RecipientTypeDetails}
                
        else {return "Nothing Found. Rethink your parameters"}
                
    }

    Get-ObjectBasedOnCommonAttribute

}



