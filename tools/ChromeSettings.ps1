# This script defines the default settings for Chrome
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ChromeHomePage
)

& "C:\Program Files\PowerShell\7\pwsh.exe" -c { @{homepage=$ChromeHomePage ;
homepage_is_newtabpage="true";
browser=(@{show_home_button="true"});
distribution=(@{make_chrome_default="true"; suppress_first_run_default_browser_prompt="true"});
first_run_tabs=@($ChromeHomePage)
} | ConvertTo-Json | Out-File -FilePath "C:\Program Files\Google\Chrome\Application\master_preferences" }
