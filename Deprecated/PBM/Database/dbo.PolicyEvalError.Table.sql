CREATE TABLE [dbo].[PolicyEvalError](
	[PolicyEvalErrorID] [int] IDENTITY(1,1) NOT NULL,
	[ServerInstance] [varchar](128) NOT NULL,
	[PolicyName] [varchar](128) NOT NULL,
	[Exception] [varchar](500) NULL,
	[PolicyEvalErrorDate] [datetime] NOT NULL,
 CONSTRAINT [PK_PolicyEvalErrorID] PRIMARY KEY CLUSTERED 
(
	[PolicyEvalErrorID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PolicyEvalError] ADD  CONSTRAINT [DF_PolicyEvalErrorDate]  DEFAULT (getdate()) FOR [PolicyEvalErrorDate]
GO
