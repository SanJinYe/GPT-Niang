function Get-WidgetStorageRoot {
  # AppData is virtualized for packaged callers. UserProfile is shared by the
  # desktop app, its children and the unpackaged Task Scheduler launcher.
  $profileRoot=[Environment]::GetFolderPath('UserProfile')
  if(!$profileRoot){throw 'User profile directory unavailable.'}
  return (Join-Path $profileRoot '.gpt-niang')
}
