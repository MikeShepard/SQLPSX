#######################
function Invoke-Coalesce
{
    param ($expression1, $expression2)

    if ($expression1)
    { $expression1 }
    else
    { $expression2 }

} #Invoke-Coalesce
