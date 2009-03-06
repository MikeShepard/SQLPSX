using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Data.Schema.ScriptDom;
using Microsoft.Data.Schema.ScriptDom.Sql;
using System.IO;

namespace SQLParser
{
    class SQLParser
    {
        private IScriptFragment fragment;
        
        public SQLParser(SqlVersion sqlVersion, bool quotedIdentifier, string inputScript)
        {
            switch (sqlVersion)
            {
                case SqlVersion.Sql80:
                    SQLParser80 (quotedIdentifier, inputScript);
                    break;
                case SqlVersion.Sql90:
                    SQLParser90 (quotedIdentifier, inputScript);
                    break;
                case SqlVersion.Sql100:
                    SQLParser100 (quotedIdentifier, inputScript);
                    break;
            }
        }
        
        private void SQLParser100 (bool quotedIdentifier, string inputScript)
        {
            TSql100Parser parser = new TSql100Parser(quotedIdentifier);
            Parse(parser, inputScript);
        }

        private void SQLParser90 (bool quotedIdentifier, string inputScript)
        {
            TSql90Parser parser90 = new TSql90Parser(quotedIdentifier);
            Parse(parser90, inputScript);
        }

        private void SQLParser80 (bool quotedIdentifier, string inputScript)
        {
            TSql80Parser parser80 = new TSql80Parser(quotedIdentifier);
            Parse(parser80, inputScript);
        }

        private void Parse(TSql100Parser parser, string inputScript)
        {
            IList<ParseError> errors;

            using (StringReader sr = new StringReader(inputScript))
            {
                fragment = parser.Parse(sr, out errors);
            }
            
            if (errors != null && errors.Count > 0)
            {
                StringBuilder sb = new StringBuilder();
                foreach (var error in errors)
                {
                    sb.AppendLine(error.Message);
                    sb.AppendLine("offset " + error.Offset.ToString());
                }
                throw new ArgumentException("InvalidSQLScript", sb.ToString());
            }
        }

        private void Parse(TSql90Parser parser, string inputScript)
        {
            IList<ParseError> errors;

            using (StringReader sr = new StringReader(inputScript))
            {
                fragment = parser.Parse(sr, out errors);
            }
            
            if (errors != null && errors.Count > 0)
            {
                StringBuilder sb = new StringBuilder();
                foreach (var error in errors)
                {
                    sb.AppendLine(error.Message);
                    sb.AppendLine("offset " + error.Offset.ToString());
                }
                throw new ArgumentException("InvalidSQLScript", sb.ToString());
            }
        }

        private void Parse(TSql80Parser parser, string inputScript)
        {
            IList<ParseError> errors;

            using (StringReader sr = new StringReader(inputScript))
            {
                fragment = parser.Parse(sr, out errors);
            }

            if (errors != null && errors.Count > 0)
            {
                StringBuilder sb = new StringBuilder();
                foreach (var error in errors)
                {
                    sb.AppendLine(error.Message);
                    sb.AppendLine("offset " + error.Offset.ToString());
                }
                throw new ArgumentException("InvalidSQLScript", sb.ToString());
            }
        }

        public IScriptFragment Fragment
        {
            get { return fragment; }
        }

        
    }
}
