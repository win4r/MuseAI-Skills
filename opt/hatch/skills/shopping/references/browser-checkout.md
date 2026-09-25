# Browser Checkout

Use this route for a purchase through a product page. Follow Purchasing Flow for preparation, missing item choices, payment setup, and final confirmation. Use Payments & Wallet for wallet operations.

Call `browser.spawn_task` with a self-contained assignment:

```json
{
  "task": "Prepare the purchase of <items and exact product URLs>. Follow these requirements: <the user's requirements>. Use these supplied details: <name, delivery address, contact details, item variants and quantities>. Follow Purchasing Flow and report the proposed purchase and any remaining setup requirements. Wait for the user's confirmation before submitting.",
  "shopping_checkout": {
    "products": [<each product hatch_telemetry_context, copied verbatim>],
    "stage": "checkout_start",
    "reason": "agentic_creation_ineligible"
  }
}
```

Include `shopping_checkout` only for Meta catalog products with a
`hatch_telemetry_context`. Copy each context whole — it carries the eligibility
snapshot that chose the route, so a route row without it records unknown
eligibility. For an initial route that never called `checkout create`, use
`stage: "checkout_start"` with `agentic_creation_ineligible` or
`user_selected_browser`. For the Shop Pay handoff, use
`stage: "payment_lane"` with `shop_pay_selected`. After any other
create attempt, use `stage: "agentic_fallback"` with `agentic_create_failed`,
`user_selected_browser`, `stripe_link_unavailable`, `provider_requires_browser`,
`agentic_completion_ineligible`, or `buyer_details_required`. Browser-discovered
products have no catalog eligibility snapshot, so omit this object for them.

Include any payment choice, Link refusal, or technical failure already established for this purchase. Keep card details out of the initial task. Follow the spawn tool's acknowledgment and asynchronous delivery instructions. Resolve payment setup when the browser returns the purchase review. Continue the same task with `browser.steer_task` as directed by Purchasing Flow.

When that payment setup selects Shop Pay, identify the chosen card to the
browser task by its exact display-safe brand and last four digits from the fresh
`wallet.list_payment_methods` result. Do not put the opaque `payment_method_id`
in the browser instruction. The trusted checkout tool resolves that ID from a
fresh wallet read before creating approval.
If the user switches cards in the approval sheet, report the masked
`approved_card` returned by BrowserTask as the card actually used, not the
originally selected card.

For multiple purchases, run browser tasks in parallel only on different sites. Two checkouts on one site share the same cart.
