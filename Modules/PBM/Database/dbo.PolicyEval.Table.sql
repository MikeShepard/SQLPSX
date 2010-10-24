CREATE TABLE [dbo].[PolicyEval](
	[PolicyEvalID] [int] IDENTITY(1,1) NOT NULL,
	[ConfigurationGroup] [varchar](128) NOT NULL,
	[PolicyCategoryFilter] [varchar](128) NOT NULL,
	[PolicyEvalMode] [varchar](32) NOT NULL,
	[PolicyName] [varchar](128) NOT NULL,
	[ServerInstance] [varchar](128) NOT NULL,
	[TargetQueryExpression] [varchar](500) NOT NULL,
	[Result] [bit] NOT NULL,
	[Exception] [varchar](500) NULL,
	[PolicyEvalDate] [datetime] NOT NULL,
 CONSTRAINT [PK_PolicyEvalID] PRIMARY KEY CLUSTERED 
(
	[PolicyEvalID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PolicyEval] ADD  CONSTRAINT [DF_PolicyEvalDate]  DEFAULT (getdate()) FOR [PolicyEvalDate]
GO
