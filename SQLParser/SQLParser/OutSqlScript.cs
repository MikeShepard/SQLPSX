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
    [Cmdlet("Out", "SqlScript")]
    public class OutSqlScript : Cmdlet
    {

        #region Parameters
        private bool alignClauseBodies;
        private bool alignColumnDefinitionFields;
        private bool alignSetClauseItem;
        private bool asKeywordOnOwnLine;
        private bool includeSemicolons;
        private int indentationSize = 4;
        private bool indentSetClause;
        private bool indentViewBody;
        private KeywordCasing keywordCasing = KeywordCasing.Uppercase;
        private bool multilineInsertSourcesList;
        private bool multilineInsertTargetsList;
        private bool multilineSelectElementsList;
        private bool multilineSetClauseItems;
        private bool multilineViewColumnsList;
        private bool multilineWherePredicatesList;
        private bool newLineBeforeCloseParenthesisInMultilineList;
        private bool newLineBeforeFromClause;
        private bool newLineBeforeGroupByClause;
        private bool newLineBeforeHavingClause;
        private bool newLineBeforeJoinClause;
        private bool newLineBeforeOpenParenthesisInMultilineList;
        private bool newLineBeforeOrderByClause;
        private bool newLineBeforeOutputClause;
        private bool newLineBeforeWhereClause;
        private SqlVersion sqlVersion = SqlVersion.Sql100;
        private string inputScript;
        private bool quotedIdentifierOff;

        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true)]
        [ValidateNotNullOrEmpty]
        public String InputScript
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

        [Parameter(Position = 4, Mandatory = false)]
        public SwitchParameter AlignClauseBodies
        {
            get
            {
                return alignClauseBodies;
            }
            set
            {
                alignClauseBodies = value;
            }
        }
        
        [Parameter(Position = 5, Mandatory = false)]
        public SwitchParameter AlignColumnDefinitionFields
        {
            get
            {
                return alignColumnDefinitionFields;
            }
            set
            {
                alignColumnDefinitionFields = value;
            }
        }
        
        [Parameter(Position = 6, Mandatory = false)]
        public SwitchParameter AlignSetClauseItem
        {
            get
            {
                return alignSetClauseItem;
            }
            set
            {
                alignSetClauseItem = value;
            }
        }
        
        [Parameter(Position = 7, Mandatory = false)]
        public SwitchParameter AsKeywordOnOwnLine
        {
            get
            {
                return asKeywordOnOwnLine;
            }
            set
            {
                asKeywordOnOwnLine = value;
            }
        }

        [Parameter(Position = 8, Mandatory = false)]
        public SwitchParameter IncludeSemicolons
        {
            get
            {
                return includeSemicolons;
            }
            set
            {
                includeSemicolons = value;
            }
        }

        [Parameter(Position = 9, Mandatory = false)]
        [ValidateNotNullOrEmpty]
        public int IndentationSize
        {
            get
            {
                return indentationSize;
            }
            set
            {
                indentationSize = value;
            }
        }

        [Parameter(Position = 10, Mandatory = false)]
        public SwitchParameter IndentSetClause
        {
            get
            {
                return indentSetClause;
            }
            set
            {
                indentSetClause = value;
            }
        }

        [Parameter(Position = 11, Mandatory = false)]
        public SwitchParameter IndentViewBody
        {
            get
            {
                return indentViewBody;
            }
            set
            {
                indentViewBody = value;
            }
        }

        [Parameter(Position = 12, Mandatory = false)]
        [ValidateNotNullOrEmpty]
        public KeywordCasing KeywordCasing
        {
            get
            {
                return keywordCasing;
            }
            set
            {
                keywordCasing = value;
            }
        }

        [Parameter(Position = 13, Mandatory = false)]
        public SwitchParameter MultilineInsertSourcesList
        {
            get
            {
                return multilineInsertSourcesList;
            }
            set
            {
                multilineInsertSourcesList = value;
            }
        }

        [Parameter(Position = 14, Mandatory = false)]
        public SwitchParameter MultilineInsertTargetsList
        {
            get
            {
                return multilineInsertTargetsList;
            }
            set
            {
                multilineInsertTargetsList = value;
            }
        }

        [Parameter(Position = 15, Mandatory = false)]
        public SwitchParameter MultilineSelectElementsList
        {
            get
            {
                return multilineSelectElementsList;
            }
            set
            {
                multilineSelectElementsList = value;
            }
        }

        [Parameter(Position = 16, Mandatory = false)]
        public SwitchParameter MultilineSetClauseItems
        {
            get
            {
                return multilineSetClauseItems;
            }
            set
            {
                multilineSetClauseItems = value;
            }
        }

        [Parameter(Position = 17, Mandatory = false)]
        public SwitchParameter MultilineViewColumnsList
        {
            get
            {
                return multilineViewColumnsList;
            }
            set
            {
                multilineViewColumnsList = value;
            }
        }

        [Parameter(Position = 18, Mandatory = false)]
        public SwitchParameter MultilineWherePredicatesList
        {
            get
            {
                return multilineWherePredicatesList;
            }
            set
            {
                multilineWherePredicatesList = value;
            }
        }

        [Parameter(Position = 19, Mandatory = false)]
        public SwitchParameter NewLineBeforeCloseParenthesisInMultilineList
        {
            get
            {
                return newLineBeforeCloseParenthesisInMultilineList;
            }
            set
            {
                newLineBeforeCloseParenthesisInMultilineList = value;
            }
        }

        [Parameter(Position = 20, Mandatory = false)]
        public SwitchParameter NewLineBeforeFromClause
        {
            get
            {
                return newLineBeforeFromClause;
            }
            set
            {
                newLineBeforeFromClause = value;
            }
        }

        [Parameter(Position = 21, Mandatory = false)]
        public SwitchParameter NewLineBeforeGroupByClause
        {
            get
            {
                return newLineBeforeGroupByClause;
            }
            set
            {
                newLineBeforeGroupByClause = value;
            }
        }

        [Parameter(Position = 22, Mandatory = false)]
        public SwitchParameter NewLineBeforeHavingClause
        {
            get
            {
                return newLineBeforeHavingClause;
            }
            set
            {
                newLineBeforeHavingClause = value;
            }
        }

        [Parameter(Position = 23, Mandatory = false)]
        public SwitchParameter NewLineBeforeJoinClause
        {
            get
            {
                return newLineBeforeJoinClause;
            }
            set
            {
                newLineBeforeJoinClause = value;
            }
        }

        [Parameter(Position = 24, Mandatory = false)]
        public SwitchParameter NewLineBeforeOpenParenthesisInMultilineList
        {
            get
            {
                return newLineBeforeOpenParenthesisInMultilineList;
            }
            set
            {
                newLineBeforeOpenParenthesisInMultilineList = value;
            }
        }

        [Parameter(Position = 25, Mandatory = false)]
        public SwitchParameter NewLineBeforeOrderByClause
        {
            get
            {
                return newLineBeforeOrderByClause;
            }
            set
            {
                newLineBeforeOrderByClause = value;
            }
        }
       
        [Parameter(Position = 26, Mandatory = false)]
        public SwitchParameter NewLineBeforeOutputClause
        {
            get
            {
                return newLineBeforeOutputClause;
            }
            set
            {
                newLineBeforeOutputClause = value;
            }
        }

        [Parameter(Position = 27, Mandatory = false)]
        public SwitchParameter NewLineBeforeWhereClause
        {
            get
            {
                return newLineBeforeWhereClause;
            }
            set
            {
                newLineBeforeWhereClause = value;
            }
        }



        #endregion

        protected override void ProcessRecord()
        {
            SqlScriptGeneratorOptions options = new SqlScriptGeneratorOptions();
            options.AlignClauseBodies = alignClauseBodies;
            options.AlignColumnDefinitionFields = alignColumnDefinitionFields;
            options.AlignSetClauseItem = alignSetClauseItem;
            options.AsKeywordOnOwnLine = asKeywordOnOwnLine;
            options.IncludeSemicolons = includeSemicolons;
            options.IndentationSize = indentationSize;
            options.IndentSetClause = indentSetClause;
            options.IndentViewBody = indentViewBody;
            options.KeywordCasing = keywordCasing;
            options.MultilineInsertSourcesList = multilineInsertSourcesList;
            options.MultilineInsertTargetsList = multilineInsertTargetsList;
            options.MultilineSelectElementsList = multilineSelectElementsList;
            options.MultilineSetClauseItems = multilineSetClauseItems;
            options.MultilineViewColumnsList = multilineViewColumnsList;
            options.MultilineWherePredicatesList = multilineWherePredicatesList;
            options.NewLineBeforeCloseParenthesisInMultilineList = newLineBeforeCloseParenthesisInMultilineList;
            options.NewLineBeforeFromClause = newLineBeforeFromClause;
            options.NewLineBeforeGroupByClause = newLineBeforeGroupByClause;
            options.NewLineBeforeHavingClause = newLineBeforeHavingClause;
            options.NewLineBeforeJoinClause = newLineBeforeJoinClause;
            options.NewLineBeforeOpenParenthesisInMultilineList = newLineBeforeOpenParenthesisInMultilineList;
            options.NewLineBeforeOrderByClause = newLineBeforeOrderByClause;
            options.NewLineBeforeOutputClause = newLineBeforeOutputClause;
            options.NewLineBeforeWhereClause = newLineBeforeWhereClause;
            options.SqlVersion = sqlVersion;

            try
            {
                SQLScripter scripter = new SQLScripter(sqlVersion, options, quotedIdentifierOff, inputScript);
                WriteObject(scripter.Script);
            }
            catch (Exception ex)
            {
                ErrorRecord errorRecord = new ErrorRecord(ex, "InvalidSQLScript", ErrorCategory.InvalidData, ex.Message);
                WriteError(errorRecord);
            }
            
        }
    }
}
