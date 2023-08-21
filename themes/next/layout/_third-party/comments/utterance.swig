{% if theme.utterance.enable %}
  <script src="https://utteranc.es/client.js"
    repo="{{ theme.utterance.repo }}"
    issue-term="{{ theme.utterance.issue_term }}"
    theme="{{ theme.utterance.theme }}"
    crossorigin="anonymous"
    async>
  </script>
{% endif %}