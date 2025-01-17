defmodule Mix.Tasks.Ash.Install do
  @moduledoc "Installs Ash into a project. Should be called with `mix igniter.install ash`"

  @shortdoc @moduledoc
  use Igniter.Mix.Task

  # I know for a fact that this will spark lots of conversation, debate and bike shedding.
  # I will direct everyone who wants to debate about it here, and that will be all.
  #
  # Number of people who wanted this to be different: 0
  @resource_default_section_order [
    :resource,
    :code_interface,
    :actions,
    :policies,
    :pub_sub,
    :preparations,
    :changes,
    :validations,
    :multitenancy,
    :attributes,
    :relationships,
    :calculations,
    :aggregates,
    :identities
  ]

  @domain_default_section_order [
    :resources,
    :policies,
    :authorization,
    :domain,
    :execution
  ]

  @impl Igniter.Mix.Task
  def info(_argv, _source) do
    %Igniter.Mix.Task.Info{
      composes: ["spark.install"],
      adds_deps: [picosat_elixir: "~> 0.2"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter, argv) do
    igniter
    |> Igniter.compose_task("spark.install")
    |> Igniter.Project.Formatter.import_dep(:ash)
    |> Igniter.Project.Config.configure(
      "config.exs",
      :spark,
      [:formatter, :"Ash.Resource", :section_order],
      @resource_default_section_order
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :spark,
      [:formatter, :"Ash.Domain", :section_order],
      @domain_default_section_order
    )
    |> then(fn igniter ->
      if "--example" in argv do
        generate_example(igniter, argv)
      else
        igniter
      end
    end)
  end

  defp generate_example(igniter, argv) do
    domain_module_name = Igniter.Code.Module.module_name("Support")
    ticket_resource = Igniter.Code.Module.module_name("Support.Ticket")
    representative_resource = Igniter.Code.Module.module_name("Support.Representative")
    ticket_status_module_name = Igniter.Code.Module.module_name("Support.Ticket.Types.Status")

    igniter
    |> Igniter.compose_task("ash.gen.domain", [inspect(domain_module_name)])
    |> Igniter.compose_task("ash.gen.enum", [
      inspect(ticket_status_module_name),
      "open,closed",
      "--short-name",
      "ticket_status"
    ])
    |> Igniter.compose_task(
      "ash.gen.resource",
      [
        inspect(ticket_resource),
        "--domain",
        inspect(domain_module_name),
        "--default-actions",
        "read",
        "--uuid-primary-key",
        "id",
        "--attribute",
        "subject:string:required:public",
        "--relationship",
        "belongs_to:representative:#{inspect(representative_resource)}:public"
      ] ++ argv
    )
    |> Igniter.compose_task(
      "ash.gen.resource",
      [
        inspect(representative_resource),
        "--domain",
        inspect(domain_module_name),
        "--default-actions",
        "read,create",
        "--uuid-primary-key",
        "id",
        "--attribute",
        "name:string:required:public",
        "--relationship",
        "has_many:tickets:#{inspect(ticket_resource)}:public"
      ] ++ argv
    )
    |> Ash.Resource.Igniter.add_attribute(ticket_resource, """
    attribute :status, :ticket_status do
      default :open
      allow_nil? false
    end
    """)
    |> Ash.Resource.Igniter.add_action(ticket_resource, """
    create :open do
      accept [:subject]
    end
    """)
    |> Ash.Resource.Igniter.add_action(ticket_resource, """
    update :close do
      accept []

      validate attribute_does_not_equal(:status, :closed) do
        message "Ticket is already closed"
      end

      change set_attribute(:status, :closed)
    end
    """)
    |> Ash.Resource.Igniter.add_action(ticket_resource, """
    update :assign do
      accept [:representative_id]
    end
    """)
  end
end
