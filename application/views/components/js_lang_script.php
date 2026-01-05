<script>
    window.lang = (function () {
        const lang = <?= json_encode(html_vars('language')) ?>;

        return (key) => {
            if (!key) {
                return lang;
            }

            if (!lang[key]) {
                // Fallback: humanize key instead of logging console error
                return String(key).replaceAll('_', ' ');
            }

            return lang[key];
        };
    })();
</script>

