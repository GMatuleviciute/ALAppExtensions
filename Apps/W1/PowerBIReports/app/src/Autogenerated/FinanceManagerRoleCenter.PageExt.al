namespace Microsoft.PowerBIReports;

using Microsoft.Finance.RoleCenters;

pageextension 36959 "Finance Manager Role Center" extends "Finance Manager Role Center"
{
    actions
    {
        addfirst(Sections)
        {
            group("PBI Reports")
            {
                Caption = 'Power BI Reports';
                Image = AnalysisView;
                ToolTip = 'Power BI reports for finance';
                action("Finance Report (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Finance Report (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Finance Report";
                    Tooltip = 'Open a Power BI Report that offers a consolidated view of all financial report pages, conveniently embedded into a single page for easy access.';
                }
                action("Financial Overview (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Financial Overview (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Financial Overview";
                    Tooltip = 'Open a Power BI Report that provides a snapshot of the organization''s financial health and performance. This page displays key performance indicators that give stakeholders a clear view of revenue, profitability, and financial stability. ';
                }
                action("Income Statement by Month (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Income Statement by Month (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Income Statement by Month";
                    Tooltip = 'Open a Power BI Report that provides a month-to-month comparative view of the net change for income statement accounts.';
                }
                action("Balance Sheet by Month (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Balance Sheet by Month (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Balance Sheet by Month";
                    Tooltip = 'Open a Power BI Report that provides a month-to-month comparative view of the balance at date for balance sheet accounts. ';
                }
                action("Budget Comparison (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Budget Comparison (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Budget Comparison";
                    Tooltip = 'Open a Power BI Report that presents a month-to-month analysis of Net Change against Budget Amounts for both Balance Sheet and Income Statement accounts. Featuring variance and variance percentage metrics, providing a clear view of how actual performance compares to budgeted targets.';
                }
                action("Liquidity KPIs (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Liquidity KPIs (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Liquidity KPIs";
                    Tooltip = 'Open a Power BI Report that offers insights into three key metrics: Current Ratio, Quick Ratio, and Cash Ratio. Visualizing these metrics over time, the report makes it easy to track trends and assess the company’s liquidity position.';
                }
                action("Profitability (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Profitability (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Profitability";
                    Tooltip = 'Open a Power BI Report that highlights Gross Profit and Net Profit, visualizing these metrics over time. It also provides detailed insights into net margins, gross profit margins, and the underlying revenue, cost and expense figures that drive them.';
                }
                action("Liabilities (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Liabilities (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Liabilities";
                    Tooltip = 'Open a Power BI Report that provides a snapshot of liability account balances as of a specific date. It also highlights key performance metrics influenced by liabilities, such as the Debt Ratio and Debt-to-Equity Ratio.';
                }
                action("EBITDA (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'EBITDA (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "EBITDA";
                    Tooltip = 'Open a Power BI Report that focuses on two key profitability metrics: EBITDA and EBIT. These figures are visualized over time to reveal trends, while Operating Revenue and Operating Expenses are also highlighted to provide supporting context for both measures.';
                }
                action("Average Collection Period (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Average Collection Period (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Average Collection Period";
                    Tooltip = 'Open a Power BI Report that analyses trends in the average collection period over time. It includes supporting details such as the Number of Days, Accounts Receivable, and Accounts Receivable (Average) to provide context and enhance the analysis.';
                }
                action("Aged Receivables (Back Dating) (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Aged Receivables (Back Dating) (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Aged Receivables (Back Dating)";
                    Tooltip = 'Open a Power BI Report that categorizes customer balances into aging buckets. It offers flexibility with filters for different payment terms, aging dates, and custom aging bucket sizes.';
                }
                action("Aged Payables (Back Dating) (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Aged Payables (Back Dating) (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Aged Payables (Back Dating)";
                    Tooltip = 'Open a Power BI Report that categorizes vendor balances into aging buckets. It offers flexibility with filters for different payment terms, aging dates, and custom aging bucket sizes.';
                }
                action("General Ledger Entries (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Ledger Entries (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "PowerBI General Ledg. Entries";
                    Tooltip = 'Open a Power BI Report that provides granular detail about the entries posted to the general ledger. ';
                }
                action("Detailed Vendor Ledger Entries (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Detailed Vendor Ledger Entries (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Detailed Vendor Ledger Entries";
                    Tooltip = 'Open a Power BI Report that provides granular detail about the entries posted to Vendor Ledger and Detailed Vendor Ledger.';
                }
                action("Detailed Cust. Ledger Entries (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Detailed Cust. Ledger Entries (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Detailed Cust. Ledger Entries";
                    Tooltip = 'Open a Power BI Report that provides granular detail about the entries posted to Customer Ledger and Detailed Customer Sub Ledger.';
                }
                action("Inventory Valuation Report (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Inventory Valuation Report (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Inventory Valuation Report";
                    Tooltip = 'Open a Power BI Report that offers a consolidated view of all inventory valuation report pages, conveniently embedded into a single page for easy access.';
                }
                action("Inventory Valuation Overview (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Inventory Valuation Overview (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Inventory Valuation Overview";
                    Tooltip = 'Open a Power BI Report that  displays the inventory ending balance against the ending balance posted to the general ledger. Inventory value by location is plotted on a bar chart which is supported by inventory metrics such as increase quantity and decrease quantity. ';
                }
                action("Inventory Valuation by Item (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Inventory Valuation by Item (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Inventory Valuation by Item";
                    Tooltip = 'Open a Power BI Report that features a Treemap that visualizes ending balance quantities by item category. It also includes a table matrix providing a detailed view of ending balances and showing fluctuations in inventory over the specified period.';
                }
                action("Inventory Valuation by Loc. (Power BI)")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Inventory Valuation by Loc. (Power BI)';
                    Image = "PowerBI";
                    RunObject = page "Inventory Valuation by Loc.";
                    Tooltip = 'Open a Power BI Report that features a Treemap that visualizes ending balance quantities by location. It also includes a table matrix providing a detailed view of ending balances and showing fluctuations in inventory over the specified period.';
                }
            }
        }
    }
}

