function FunctionOne ([switch] $SwitchParam)
{
    if ($SwitchParam)
    {
        return 'SwitchParam was set'
    }
    else
    {
        return 'SwitchParam was not set'
    }
}

function FunctionTwo
{
    return 'I get executed'
}