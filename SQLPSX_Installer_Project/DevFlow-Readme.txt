New SQLPSX_Install Document

Folder -> SQLPSX_Installer_Project
		
		Folders

		|--> Add_files_to_SQLPSX  (these files need to be added to your SQLPSX.zip file)

		|--> Current_SQLPSX_ZIP	 (here's a copy of your SQLPSX.zip file)

		|--> Logos  ( here's Laerte's logo and a bmp file I created from it)

		|--> Source ( Here the main source code of SQLPSX_Install built in Sapien's Primalform ).

		|--> SQLPSX_V2_Install ( This is the folder you need to zip and distribute. SQLPSX_2.1.zip is already included in it. )


What's included in the "Add_files_to_SQLPSX" folder?

There are two files:
1. Ionic.Zip.dll - free codeplex dll for extracting (& zip) files.
2. SQLPSX_LoadModules.ps1 - This *script will load all the SQPSX modules that exist in the x:\Windows\..\WindowsPowerShell\Modules\SQLPSX.. folder.

*note: This script line will be installed in either of the existing profiles (User or Windows) BUT is commented out so the user can manually enable 
it after the installation.  For the future I will include a menu so they can pick to load or not.



Additional notes:

1. I have successfully test this solution on: Windows 7(64/32bit), Windows 2008 SP1 (32bit), Windows 2008R2 (x:\Windows), and Windows XP.
2. There's two installer for either 32 or 64 bit environments.
3. Also, I have tested that it will install the modules if the Windows location is not c:\.
4. The folder "SQLPSX_V2 Install" is the one your zipped and distribute:
     1. This will build a folder with the files you need to pick to install SQLPSX_v2.1 using either: SQLPSX_Install_32.exe or SQLPSX_Install_64.exe
5. Simple install doc included.


For more information, email at: 

maxt@putittogether.net

Blog sites at: 
1. http://max-pit.spaces.live.com/  (new blog site coming soon)
http://www.flpsug.com/


# DISCLAIMER:
© 2010 PutItTogether (in collaboration with Chad Miller SQLPSX and contributors). All rights reserved. Demo/Sample scripts in this presentation are not supported under any Microsoft support program or service. The Demos & sample scripts are provided AS IS without warranty of any kind. 
I (the presenter) disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the 
Demo/sample scripts and documentation remains with you. In no event shall I (the author), its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, 
without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the Demo/sample scripts or documentation, even if I 
has been advised of the possibility of such damages. 

We are using the following solution:
© 2010 Sapien - PrimalForms 2009 - use to build this installer application.
© 2010 DotNetZip - Zip and Unzip in C#, VB, any .NET language
DotNetZip is an easy-to-use, FAST, FREE class library and toolset for manipulating zip files or folders. 
Zip and Unzip is easy: with DotNetZip, .NET applications written in VB, C# - any .NET language - can easily 
create, read, extract, or update zip files. For Mono or MS .NET.


Changes log - 0.1 - 03/18/2010, 1734 - Max Trinidad
1. Add the "Close" Button.
2. Rename SQLPSX folder from "..\Module\SQLPSX_V2" to "..\Module\SQLPSX".
3. Create a single installer, its 32 bit but should install OK on 64bit machines.
4. Delete both SQLPSX_Install32 and 64 exe's.

Changes log - 0.1a - 03/18/2010, 17:58 - Max Trinidad
1. Put back both Installer 32/64 because the 32bit will not create the SQLPSX folder.

Changes log - 0.2 - 03/24/2010, 0922 - Max Trinidad
1. I PSscript - "SQLPSX_LoadModules.ps1", added new modules to be loaded: adolib,SQLmaint, & SQLIse.

Changes log – 0.3 – 03/31/2010, 2143 – Max Trinidad
1.Change the module location to match for User and Windows Profile.
2.Update Installer instructions word document.

Change log - 0.4 - 04/04/2010, 10:04 - Max Trinidad
1.Changes to accomodate modules folders structure.
2.Change to the "SQLPSX_LoadModules.ps1" to properly look for the PSModule path.
3.Rename the "Simple SQLPSX Installer steps.docx" to "Readme SQLPSX Installer.docx".

Change log - 0.5 - 04/05/2010, 21:45 - Max Trinidad/Bernd
1. Add changes to ps script modules path in the "SQLPSX_LoadModules.ps1"
2. Also, incorporate suggested changes by Bernd to automate the commented line to execute "SQLPSX_LoadModules.ps1"
   for either Windows and User profile.


Change log – 0.6 – 05/7-8/2010 14;33 – Max Trinidad
1 Change import to load SQLPSX.psm1
2 Change commented line to properly run the SQLPSX.psm1.

Change log - 0.7 - 05/10/2010 17:20 - Max Trinidad
1. Found bug missing path to Windows\system32 PowerShell modules.




