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
    class SQLScripter
    {
        private String script;
              
        public SQLScripter (SqlVersion sqlVersion, SqlScriptGeneratorOptions options, bool quotedIdentifier, String inputScript)
        {
            switch (sqlVersion)
            {
                case SqlVersion.Sql80:
                    SQLScripter100(options, quotedIdentifier, inputScript);
                    break;
                case SqlVersion.Sql90:
                    SQLScripter100(options, quotedIdentifier, inputScript);
                    break;
                case SqlVersion.Sql100:
                    SQLScripter100(options, quotedIdentifier, inputScript);
                    break;
            }
        }

        private void SQLScripter100 (SqlScriptGeneratorOptions options, bool quotedIdentifier, String inputScript)
        {
            Sql100ScriptGenerator scripter = new Sql100ScriptGenerator(options);
            Generate(scripter, quotedIdentifier, inputScript);
        }

        private void SQLScripter90(SqlScriptGeneratorOptions options, bool quotedIdentifier, String inputScript)
        {
            Sql90ScriptGenerator scripter = new Sql90ScriptGenerator(options);
            Generate(scripter, quotedIdentifier, inputScript);
        }

        private void SQLScripter80(SqlScriptGeneratorOptions options, bool quotedIdentifier, String inputScript)
        {
            Sql80ScriptGenerator scripter = new Sql80ScriptGenerator(options);
            Generate(scripter, quotedIdentifier, inputScript);
        }

        private void Generate(Sql100ScriptGenerator scripter, bool quotedIdentifier, String inputScript)
        {
            SQLParser parser = new SQLParser(SqlVersion.Sql100, quotedIdentifier, inputScript);
            scripter.GenerateScript(parser.Fragment, out script);
        }

        private void Generate(Sql90ScriptGenerator scripter, bool quotedIdentifier, String inputScript)
        {
            SQLParser parser = new SQLParser(SqlVersion.Sql90, quotedIdentifier, inputScript);
            scripter.GenerateScript(parser.Fragment, out script);
        }
        
        private void Generate(Sql80ScriptGenerator scripter, bool quotedIdentifier, String inputScript)
        {
            SQLParser parser = new SQLParser(SqlVersion.Sql80, quotedIdentifier, inputScript);
            scripter.GenerateScript(parser.Fragment, out script);
        }

        public String Script
        {
            get { return script; }
        }
                      
    }
}
