// LCP Ruby — Sprockets manifest
//
// Load order matters:
//   utils         — defines LcpRuby.getFieldValue(), used by conditional_rendering,
//                   cascading_selects, and tom_select_init
//   i18n          — defines window.LcpI18n (ERB-processed translations), read by
//                   tom_select_init, inline_create, and cascading_selects
//   inline_create — defines window.lcpOpenInlineCreate(), called at runtime by
//                   cascading_selects (re-attaches footer) and tom_select_init
//
//= require lcp_ruby/utils
//= require lcp_ruby/i18n
//= require lcp_ruby/form_handling
//= require lcp_ruby/ui_components
//= require lcp_ruby/nested_forms
//= require lcp_ruby/input_enhancements
//= require lcp_ruby/conditional_rendering
//= require lcp_ruby/inline_create
//= require lcp_ruby/cascading_selects
//= require lcp_ruby/tom_select_init
//= require lcp_ruby/tree_select
//= require lcp_ruby/file_upload
//= require lcp_ruby/direct_upload
