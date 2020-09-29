# frozen_string_literal: true

module API
  module V2
    module CoinGecko
      class HistoricalTrades < Grape::API
        desc 'Get recent trades on market'
        params do
          requires :ticker_id,
                   type: String,
                   desc: 'A pair such as "LTC_BTC"',
                   coerce_with: ->(name) { name.strip.split('_').join }
          optional :type,
                   type: String,
                   values: { value: %w(buy sell), message: 'coingecko.historical_trades.invalid_type' },
                   desc: 'To indicate nature of trade - buy/sell'
          optional :limit,
                   type: Integer,
                   values: { value: 0..1000, message: 'coingecko.historical_trades.invalid_limit' },
                   desc: 'Number of historical trades to retrieve from time of query. [0, 200, 500...]. 0 returns full history'
          optional :start_time,
                   type: Integer,
                   desc: '',
                   coerce_with: ->(start_time) { Time.parse(start_time).to_i }
          optional :end_time,
                   type: Integer,
                   desc: '',
                   coerce_with: ->(end_time) { Time.parse(end_time).to_i }
        end
        get '/historical_trades' do
          market = ::Market.find(params[:ticker_id])

          filters = declared(params, include_missing: false)
                    .except(:ticker_id)
                    .merge(market: market.id)

          formatted_trades = {
            'buy' => [],
            'sell' => []
          }

          trades_query = 'SELECT id, price, amount, total, taker_type, market, created_at FROM trades WHERE market=%{market}'

          if params[:type].present?
            trades_query += " AND taker_type=%{type}"
          end

          if params[:start_time].present?
            trades_query += " AND created_at>=%{start_time}"
          end

          if params[:end_time].present?
            trades_query += " AND created_at>=%{end_time}"
          end

          trades_query += " ORDER BY desc"

          unless params[:limit].to_d.zero?
            trades_query += " LIMIT %{limit}"
          end

          Trade.public_from_influx_with_filters(market.id, trades_query, filters).each do |trade|
            formatted_trades[trade[:taker_type]] << format_trade(trade)
          end

          formatted_trades
        end
      end
    end
  end
end
