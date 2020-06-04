# This script defines the default settings for Chrome
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ChromeHomePage
)

& "C:\Program Files\PowerShell\7\pwsh.exe" -c { @{homepage="https://www.figma.com/proto/RFUMduUsLUxPYvLjnULsUd/Documentation-Quickstart-Marisa?node-id=120%3A1590&viewport=181%2C380%2C0.125&scaling=min-zoom" ;
homepage_is_newtabpage="true";
browser=(@{show_home_button="true"});
distribution=(@{make_chrome_default="true"; suppress_first_run_default_browser_prompt="true"});
first_run_tabs=@("https://www.figma.com/proto/RFUMduUsLUxPYvLjnULsUd/Documentation-Quickstart-Marisa?node-id=120%3A1590&viewport=181%2C380%2C0.125&scaling=min-zoom")
} | ConvertTo-Json | Out-File -FilePath "C:\Program Files (x86)\Google\Chrome\Application\master_preferences" }
