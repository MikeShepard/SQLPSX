New-Window -Width 300 -Height 300 -WindowStartupLocation CenterScreen -Show -DataContext {
    $ds
} {

   $detailTemplate  = ConvertTo-DataTemplate -control (New-TextBlock) -binding @{Text = $table.Columns["Table"]}
   $masterTemplate  = New-HierarchicalDataTemplate -ItemsSource (New-Binding -IsAsync -Path "Database2Table") -ItemTemplate $detailTemplate
    New-TreeView -ItemTemplate $masterTemplate -DataBinding @{
        ItemsSource = New-Binding -IsAsync -Path "Database"
    }
}
