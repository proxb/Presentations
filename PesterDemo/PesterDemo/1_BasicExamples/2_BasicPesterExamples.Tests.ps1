#region Show Describe and Context
<#
    Provides a way to organize the testing
#> 
Describe 'This describes what we should do' {
    Context 'Additional sectioning off of data to test' {        
    }
    Context 'More additional sectioning off of data to test' {       
    }
}
Describe 'This describes what we should do with a Tag: Describe1' -Tags Describe1 {
    Context 'This is a context where I section off a test' {        
    }
    Context 'More additional sectioning off of data to test' {       
    }
}
Describe 'This describes what we should do with another Tag: Describe2' -Tags Describe2 {
    Context 'Sectioning off tests' {        
    }
    Context 'More additional sectioning off of data to test' {       
    }
}
Describe 'Test1' {
    Context 'Sectioning off tests' {        
    }
    Context 'More additional sectioning off of data to test' {       
    }
}
Describe 'This describes what we should do based on information in this Describe block using TestName parameter' {
    Context 'Sectioning off tests' {        
    }
    Context 'More additional sectioning off of data to test' {       
    }
}
#endregion Show Describe and Context 