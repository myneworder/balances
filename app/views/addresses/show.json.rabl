object @address
cache @address

attributes :id,
           :user_id,
           :created_at,
           :first_tx_at,
           :currency,
           :display_name,
           :integration,
           :name,
           :notes,
           :public_address

node(:short_name) { |address| address.get_currency.short_name }

node(:currency_image_path) do |address|
  image_path "currencies/#{address.currency.downcase}.svg"
end

node(:balance) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.balance, precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_btc) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_btc(address.balance), precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_doge) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_doge(address.balance), precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_ltc) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_ltc(address.balance), precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_str) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_str(address.balance), precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_vtc) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_vtc(address.balance), precision: 8, strip_insignificant_zeros: true)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_usd) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_usd(address.balance), precision: 2)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_eur) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_eur(address.balance), precision: 2)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_gbp) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_gbp(address.balance), precision: 2)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end

node(:balance_jpy) do |address|
  rounded = ActiveSupport::NumberHelper.number_to_rounded(address.get_currency.to_jpy(address.balance), precision: 2)
  ActiveSupport::NumberHelper.number_to_delimited(rounded)
end
