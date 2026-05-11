---
name: budget-tracker
description: Track monthly spending, analyze budget vs actual, calculate savings rate. Use when user says "budget review", "monthly spending", "how much did I spend", "savings rate", or "track expenses". Analyzes bank CSVs and generates markdown budget reports.
---

# Budget Tracker

Analyze spending, categorize expenses, track savings progress toward $30K goal.

## Workflow

### 1. Get Transaction Data
Ask user for bank/card CSV exports (same as just-fucking-cancel):
- Apple Card: Wallet → Card Balance → Export
- Chase: Accounts → Download activity → CSV
- Multiple sources OK - will merge

### 2. Categorize Transactions
Auto-categorize based on merchant patterns:

| Category | Example Merchants |
|----------|-------------------|
| Housing | Rent, Mortgage, HOA |
| Utilities | PG&E, Comcast, Water |
| Food & Dining | Restaurants, Groceries, DoorDash |
| Transportation | Gas, Uber, BART, Parking |
| Shopping | Amazon, Target, clothing |
| Entertainment | Netflix, Spotify, movies |
| Subscriptions | SaaS, memberships (flag for audit) |
| Health | Doctor, pharmacy, gym |
| Travel | Airlines, hotels, Airbnb |
| Income | Salary, transfers in |
| Other | Uncategorized |

Flag ambiguous transactions for user confirmation.

### 3. Calculate Metrics

**Monthly Summary:**
- Total Income
- Total Expenses
- Net (Income - Expenses)
- Savings Rate (Net / Income × 100)

**Category Breakdown:**
- Amount per category
- % of total spending
- vs previous month (if available)

**Savings Progress:**
- 2026 Goal: $30,000
- YTD Saved: (sum of monthly nets)
- On Track: Yes/No (compare to linear goal)
- Monthly target to hit goal

### 4. Generate Budget Report

Output to: `beru-workspace/1-Projects/personal-finance-2026-01/data/budgets/budget-YYYY-MM.md`

```markdown
# Budget Report - [Month Year]

## Summary
| Metric | Amount |
|--------|--------|
| Income | $X,XXX |
| Expenses | $X,XXX |
| Net | $X,XXX |
| Savings Rate | XX% |

## Savings Progress
- 2026 Goal: $30,000
- YTD Saved: $X,XXX
- On Track: ✅/❌
- Need $X,XXX/month remaining

## Spending by Category
| Category | Amount | % | vs Last Month |
|----------|--------|---|---------------|
| Housing | $X,XXX | XX% | - |
| ... | ... | ... | ... |

## Top Expenses
1. [Merchant] - $XXX
2. ...

## Subscriptions Flagged
- [Service] - $XX/month (consider audit)

## Notes
[Any observations or recommendations]
```

### 5. Trend Analysis (Optional)
If multiple months available:
- Spending trends by category
- Savings rate over time
- Seasonal patterns
- Recommendations

## Integration with just-fucking-cancel

When subscriptions are found:
1. List them in "Subscriptions Flagged" section
2. Suggest running `/just-fucking-cancel` for full audit
3. After audit, update totals with cancelled amounts

## Privacy

All data stays local. CSV files processed in-session only.
Budget reports saved to local project folder.
