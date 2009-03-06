using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.ComponentModel;

namespace SQLParser
{
    [RunInstaller(true)]
    public class SQLParserSnapIn : PSSnapIn
    {
        public override string Name
        {
            get { return "SQLParser"; }
        }
        public override string Vendor
        {
            get { return ""; }
        }
        public override string VendorResource
        {
            get { return "SQLParser,"; }
        }
        public override string Description
        {
            get { return "Registers the CmdLets and Providers in this assembly"; }
        }
        public override string DescriptionResource
        {
            get { return "SQLParser,Registers the CmdLets and Providers in this assembly"; }
        }
    }
}
