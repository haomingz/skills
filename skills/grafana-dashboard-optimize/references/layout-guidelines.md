# Layout Guidelines

## Recommended Flow

Overview -> Symptoms -> Root Cause

## Row Usage

Use `panels.rowPanel` for rows and collapse detailed sections:

```jsonnet
local overviewRow = panels.rowPanel('Overview', collapsed=false);
local detailsRow = panels.rowPanel('Details', collapsed=true)
  + g.panel.row.withPanels([
    panelA,
    panelB,
  ]);
```

## Grid Tips

- Use consistent widths (6, 8, 12, 24)
- Critical metrics belong top-left
- Keep overview row visible by default