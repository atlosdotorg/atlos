defmodule Platform.FeatureFlags do
  def feature_available?(feature_key) do
    Application.get_env(:platform, :features)[feature_key] == true
  end
end
