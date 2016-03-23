class SourceDecorator < Draper::Decorator
  delegate_all
  decorates_association :group

  def group_id
    model.group.name
  end

  def display_name
    title
  end

  def state
    human_state_name
  end

  def id
    name
  end

  def by_month
    { "with_events" => with_events_by_month_count,
      "without_events" => without_events_by_month_count,
      "not_updated" => not_updated_by_month_count }
  end
end
