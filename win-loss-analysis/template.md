# {{Quarter}} Win/Loss Report

*Assembled {{report_date}}*

# Acquisition

**{{acq_win_rate}}% Win Rate**

* **{{acq_wins}} Wins** & {{acq_losses}} Losses / {{acq_closed}} Closed Opps{{acq_pending_inline}}

**Win Notes**

* **${{acq_won_arr}} New ARR (${{acq_arr_per_logo}} / logo)**
* **{{acq_total}} wins · {{acq_active}} active · {{acq_purchasing}} purchasing** ([view usage in BI]({{acq_bi_usage_url}}))
  * {{acq_users}} users active across these accounts
  * **${{acq_usage_value}} in product usage**
  * {{acq_adoption_summary}}
{{acq_adoption_callouts}}
* **Subscription Info** ([view subscriptions in BI]({{acq_bi_subs_url}}))
  * {{acq_subs_summary}}
  * **{{acq_integration_count}} of {{acq_wins}} on a paid integration add-on**

**Close-Loss Notes**

* **${{acq_lost_arr}} ARR**
{{acq_loss_segmentation}}

**Product Topics from Losses**

{{acq_loss_themes}}

# Retention

**{{ret_win_rate}}% Win Rate**
{{ret_pending_pct_line}}

* **{{ret_wins}} Wins** & {{ret_losses}} Losses / {{ret_closed}} Closed Opps + {{ret_pending}} pending

**Win Notes**

* **${{ret_won_arr}} ARR Renewed ({{ret_arr_pct}}%)**

**Loss Notes**

* **${{ret_churned_arr}} ARR churned**
{{ret_loss_themes}}

# Churn Risk

---

*Raw data spreadsheet: {{spreadsheet_path}}*

{{vertical_analysis_appendix}}
