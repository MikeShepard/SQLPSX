using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Collections;
using Microsoft.Data.Schema.ScriptDom;
using Microsoft.Data.Schema.ScriptDom.Sql;
using System.Data;
using System.Linq;
using System.IO;

namespace SQLParser
{
    [Cmdlet("Test", "SqlScript")]
    public class TestSqlScript : Cmdlet
    {

        #region Parameters
        private string inputScript;
        private bool quotedIdentifierOff;
        private SqlVersion sqlVersion = SqlVersion.Sql100;

        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true)]
        [ValidateNotNullOrEmpty]
        public string InputScript
        {
            get
            {
                return inputScript;
            }
            set
            {
                inputScript = value;
            }
        }

        [Parameter(Position = 2, Mandatory = false)]
        public SwitchParameter QuotedIdentifierOff
        {
            get
            {
                return quotedIdentifierOff;
            }
            set
            {
                quotedIdentifierOff = value;
            }
        }

        [Parameter(Position = 3, Mandatory = false)]
        [ValidateNotNullOrEmpty]
        public SqlVersion SqlVersion
        {
            get
            {
                return sqlVersion;
            }
            set
            {
                sqlVersion = value;
            }
        }

        #endregion

        protected override void ProcessRecord()
        {
            bool quotedIdentifier;

            if (quotedIdentifierOff)
            {
                quotedIdentifier = false;
            }
            else
            {
                quotedIdentifier = true;
            }
            
            try
            {
                SQLParser parser = new SQLParser(sqlVersion, quotedIdentifier, inputScript);
                WriteObject(true);
            }
            catch (Exception ex)
            {
                WriteObject(false);
                ErrorRecord errorRecord = new ErrorRecord(ex, "InvalidSQLScript", ErrorCategory.InvalidData, ex.Message);
                WriteError(errorRecord);
            }
        }
    }
}
