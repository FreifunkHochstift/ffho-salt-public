monitoring:
{% if grains['id'] in ["<id>"] %}
  users:
    ffho-ops:
      display_name: "<name>"
      telegram_chat_id: "-<group id>"

    # ...

  private:
    telegram_bot_token: "<token>"
{% endif %}
