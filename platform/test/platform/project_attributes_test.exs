defmodule Platform.ProjectAttributesTest do
  use Platform.DataCase, async: true

  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Projects
  alias Platform.Projects.ProjectAttribute

  import Platform.ProjectsFixtures
  import Platform.MaterialFixtures

  # Adds a user-defined-options multi-select ("License Plates") to the project and
  # returns {project, attribute_id}.
  defp project_with_open_attribute(opts \\ []) do
    project = project_fixture()

    {:ok, project} =
      Projects.update_project(project, %{
        "attributes" => %{
          "0" => %{
            "name" => "License Plates",
            "type" => "multi_select",
            "options_json" => Jason.encode!(Keyword.get(opts, :options, [])),
            "allow_user_defined_options" => "true"
          }
        }
      })

    attr = project.attributes |> Enum.find(&(&1.name == "License Plates"))
    {project, attr.id}
  end

  describe "ProjectAttribute changeset" do
    test "allows a multi-select with no predefined options when user-defined options are on" do
      changeset =
        ProjectAttribute.changeset(%ProjectAttribute{}, %{
          "name" => "License Plates",
          "type" => "multi_select",
          "options_json" => "[]",
          "allow_user_defined_options" => "true"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :allow_user_defined_options) == true
      assert Ecto.Changeset.get_field(changeset, :options) == []
    end

    test "still refuses to let a closed multi-select have its options cleared" do
      changeset =
        ProjectAttribute.changeset(
          %ProjectAttribute{name: "Impact", type: :multi_select, options: ["Structure"]},
          %{"options_json" => "[]"}
        )

      refute changeset.valid?
      assert %{options: _} = errors_on(changeset)
    end

    test "lets an open multi-select have its options cleared" do
      changeset =
        ProjectAttribute.changeset(
          %ProjectAttribute{
            name: "License Plates",
            type: :multi_select,
            options: ["AB-123-CD"],
            allow_user_defined_options: true
          },
          %{"options_json" => "[]"}
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :options) == []
    end

    test "predefined options and user-defined options can coexist" do
      changeset =
        ProjectAttribute.changeset(%ProjectAttribute{}, %{
          "name" => "License Plates",
          "type" => "multi_select",
          "options_json" => Jason.encode!(["AB-123-CD"]),
          "allow_user_defined_options" => "true"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :options) == ["AB-123-CD"]
    end

    test "forces the flag off for types that don't support it" do
      for type <- ["select", "text", "date"] do
        changeset =
          ProjectAttribute.changeset(%ProjectAttribute{}, %{
            "name" => "Something",
            "type" => type,
            "options_json" => Jason.encode!(["A"]),
            "allow_user_defined_options" => "true"
          })

        assert changeset.valid?, "expected #{type} to be valid"

        assert Ecto.Changeset.get_field(changeset, :allow_user_defined_options) == false,
               "expected #{type} to have user-defined options forced off"
      end
    end

    test "to_attribute/1 carries the flag through to the core Attribute" do
      attr = %ProjectAttribute{
        id: Ecto.UUID.generate(),
        name: "License Plates",
        type: :multi_select,
        options: [],
        allow_user_defined_options: true
      }

      converted = ProjectAttribute.to_attribute(attr)

      assert converted.allow_user_defined_options == true
      assert Attribute.allow_user_defined_options(converted) == true
    end

    test "to_attribute/1 leaves ordinary multi-selects closed" do
      attr = %ProjectAttribute{
        id: Ecto.UUID.generate(),
        name: "Impact",
        type: :multi_select,
        options: ["Structure"]
      }

      assert Attribute.allow_user_defined_options(ProjectAttribute.to_attribute(attr)) == false
    end
  end

  describe "validation of media values" do
    test "accepts values outside the option list, and rejects them when the flag is off" do
      {project, attr_id} = project_with_open_attribute(options: ["KNOWN-1"])
      media = media_fixture(%{project_id: project.id})
      attribute = Attribute.get_attribute(attr_id, project: project)

      {:ok, media} =
        Material.update_media_attribute(media, attribute, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["BRAND-NEW-PLATE"]}}
        })

      assert (media.project_attributes |> Enum.find(&(&1.id == attr_id))).value == [
               "BRAND-NEW-PLATE"
             ]

      # With the flag off, the same value is rejected.
      closed = %{attribute | allow_user_defined_options: false, options: ["KNOWN-1"]}

      {:error, changeset} =
        Material.update_media_attribute(media, closed, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["ANOTHER-NEW-PLATE"]}}
        })

      refute changeset.valid?
    end
  end

  describe "get_values_of_attribute/2 for project attributes" do
    test "returns the distinct values in use, scoped to the given projects" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)

      for value <- [["AB-123-CD", "XY-999-ZZ"], ["AB-123-CD"]] do
        media = media_fixture(%{project_id: project.id})
        {:ok, _} = Material.update_media_attribute_internal(media, attribute, value)
      end

      values = Material.get_values_of_attribute(attribute, projects: [project])

      assert Enum.sort(values) == ["AB-123-CD", "XY-999-ZZ"]
    end

    test "does not leak values from other projects when scoped" do
      {project_a, attr_a} = project_with_open_attribute()
      attribute_a = Attribute.get_attribute(attr_a, project: project_a)

      media = media_fixture(%{project_id: project_a.id})

      {:ok, _} = Material.update_media_attribute_internal(media, attribute_a, ["ONLY-IN-A"])

      # A different project, with its own attribute, sees nothing from project A.
      project_b = project_fixture(%{code: "code2"})

      {:ok, project_b} =
        Projects.update_project(project_b, %{
          "attributes" => %{
            "0" => %{
              "name" => "License Plates",
              "type" => "multi_select",
              "options_json" => "[]",
              "allow_user_defined_options" => "true"
            }
          }
        })

      attr_b = (project_b.attributes |> Enum.find(&(&1.name == "License Plates"))).id
      attribute_b = Attribute.get_attribute(attr_b, project: project_b)

      assert Material.get_values_of_attribute(attribute_b, projects: [project_b]) == []
      assert Material.get_values_of_attribute(attribute_a, projects: [project_a]) == ["ONLY-IN-A"]
    end

    test "returns an empty list when nothing is in use" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)

      assert Material.get_values_of_attribute(attribute, projects: [project]) == []
    end

    test "ignores values that aren't arrays instead of raising" do
      project = project_fixture()

      {:ok, project} =
        Projects.update_project(project, %{
          "attributes" => %{
            "0" => %{
              "name" => "License Plates",
              "type" => "multi_select",
              "options_json" => "[]",
              "allow_user_defined_options" => "true"
            },
            "1" => %{
              "name" => "Notes",
              "type" => "text"
            }
          }
        })

      plates = project.attributes |> Enum.find(&(&1.name == "License Plates"))
      notes = project.attributes |> Enum.find(&(&1.name == "Notes"))

      media = media_fixture(%{project_id: project.id})
      notes_attribute = Attribute.get_attribute(notes.id, project: project)

      {:ok, _} =
        Material.update_media_attribute_internal(media, notes_attribute, "a scalar string")

      plates_attribute = Attribute.get_attribute(plates.id, project: project)

      # The scalar-valued text attribute must not break the plate lookup.
      assert Material.get_values_of_attribute(plates_attribute, projects: [project]) == []
    end
  end

  describe "stored vocabulary" do
    defp vocabulary(project_id, attr_id) do
      Projects.get_project!(project_id).attributes
      |> Enum.find(&(&1.id == attr_id))
      |> Map.get(:options)
    end

    test "a newly entered value is persisted into the attribute's options" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)
      media = media_fixture(%{project_id: project.id})

      assert vocabulary(project.id, attr_id) == []

      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["AB-123-CD"])

      assert vocabulary(project.id, attr_id) == ["AB-123-CD"]
    end

    test "a value survives after the last incident using it drops it" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)
      media = media_fixture(%{project_id: project.id})

      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["KEEP-ME", "DROP-ME"])
      assert Enum.sort(vocabulary(project.id, attr_id)) == ["DROP-ME", "KEEP-ME"]

      # Remove it from the only incident that had it.
      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["KEEP-ME"])
      Material.invalidate_attribute_values_cache()

      # No longer in use...
      assert Material.get_values_of_attribute(attribute, projects: [project]) == ["KEEP-ME"]
      # ...but still in the vocabulary.
      assert Enum.sort(vocabulary(project.id, attr_id)) == ["DROP-ME", "KEEP-ME"]
    end

    test "the vocabulary only grows, and never duplicates" do
      {project, attr_id} = project_with_open_attribute(options: ["PREDEFINED"])
      attribute = Attribute.get_attribute(attr_id, project: project)

      for value <- [["PREDEFINED", "A"], ["A", "B"], ["B"]] do
        media = media_fixture(%{project_id: project.id})
        {:ok, _} = Material.update_media_attribute_internal(media, attribute, value)
      end

      vocab = vocabulary(project.id, attr_id)
      assert Enum.sort(vocab) == ["A", "B", "PREDEFINED"]
      assert Enum.uniq(vocab) == vocab
    end

    test "closed attributes never absorb anything" do
      project = project_fixture()

      {:ok, project} =
        Projects.update_project(project, %{
          "attributes" => %{
            "0" => %{
              "name" => "Impact",
              "type" => "multi_select",
              "options_json" => Jason.encode!(["Structure"])
            }
          }
        })

      attr = project.attributes |> Enum.find(&(&1.name == "Impact"))
      attribute = Attribute.get_attribute(attr.id, project: project)
      media = media_fixture(%{project_id: project.id})

      # `_internal` bypasses select validation, so this writes an off-list value.
      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["Not An Option"])

      assert vocabulary(project.id, attr.id) == ["Structure"]
    end

    test "a value too long to store is rejected instead of being silently dropped" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)
      media = media_fixture(%{project_id: project.id})

      long = String.duplicate("x", ProjectAttribute.max_option_length() + 1)

      {:error, changeset} =
        Material.update_media_attribute(media, attribute, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["SHORT", long]}}
        })

      refute changeset.valid?

      assert changeset
             |> Ecto.Changeset.traverse_errors(fn {m, _} -> m end)
             |> Map.get(:project_attributes)
             |> Enum.any?(fn errs ->
               Enum.any?(Map.get(errs, :value, []), &String.contains?(&1, "too long"))
             end)

      # Nothing was written, so the incident and the vocabulary stay in step.
      assert vocabulary(project.id, attr_id) == []

      assert (Material.get_media!(media.id).project_attributes
              |> Enum.find(&(&1.id == attr_id))).value in [nil, []]
    end

    test "a full vocabulary refuses new values rather than diverging" do
      max = ProjectAttribute.max_options()
      full = Enum.map(1..max, &"PLATE-#{&1}")
      {project, attr_id} = project_with_open_attribute(options: full)
      attribute = Attribute.get_attribute(attr_id, project: project)
      media = media_fixture(%{project_id: project.id})

      # An existing value is still fine -- it needs no room.
      {:ok, _} =
        Material.update_media_attribute(media, attribute, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["PLATE-1"]}}
        })

      # A brand-new one has nowhere to go, so it is refused.
      {:error, changeset} =
        Material.update_media_attribute(media, attribute, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["PLATE-1", "OVERFLOW"]}}
        })

      refute changeset.valid?
    end

    test "every value in use is always a valid option (the invariant uncheck relies on)" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)

      for value <- [["A-1", "A-2"], ["A-2", "B-1"], ["C-1"]] do
        media = media_fixture(%{project_id: project.id})

        {:ok, _} =
          Material.update_media_attribute(media, attribute, %{
            "project_attributes" => %{"0" => %{"id" => attr_id, "value" => value}}
          })
      end

      Material.invalidate_attribute_values_cache()
      in_use = Material.get_values_of_attribute(attribute, projects: [project])
      stored = vocabulary(project.id, attr_id)

      assert Enum.sort(in_use -- stored) == [], "values in use that aren't stored options"
    end

    test "unchecking the flag leaves no stranded values" do
      {project, attr_id} = project_with_open_attribute()
      attribute = Attribute.get_attribute(attr_id, project: project)
      media = media_fixture(%{project_id: project.id})

      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["AB-123-CD"])

      # Close the attribute back up.
      project = Projects.get_project!(project.id)

      attrs =
        project.attributes
        |> Enum.map(
          &%{
            "id" => &1.id,
            "name" => &1.name,
            "type" => to_string(&1.type),
            "options_json" => Jason.encode!(&1.options),
            "allow_user_defined_options" =>
              if(&1.id == attr_id, do: "false", else: to_string(&1.allow_user_defined_options))
          }
        )
        |> Enum.with_index()
        |> Map.new(fn {a, i} -> {to_string(i), a} end)

      {:ok, closed_project} = Projects.update_project(project, %{"attributes" => attrs})
      closed = Attribute.get_attribute(attr_id, project: closed_project)

      refute closed.allow_user_defined_options
      # The value that was entered while open is now a legitimate option.
      assert "AB-123-CD" in Attribute.options(closed)

      # ...so re-saving the incident's existing value still validates.
      {:ok, _} =
        Material.update_media_attribute(media, closed, %{
          "project_attributes" => %{"0" => %{"id" => attr_id, "value" => ["AB-123-CD"]}}
        })
    end

    test "absorbs values arriving through a bulk import" do
      {project, attr_id} = project_with_open_attribute()

      cs =
        Material.bulk_import_change(
          %{
            "description" => "imported",
            "sensitive" => "Not Sensitive",
            "status" => "To Do",
            "license plates" => "BULK-1, BULK-2"
          },
          project
        )

      assert cs.valid?
      {:ok, _} = Material.bulk_import_create(%Platform.Material.Media{}, %{
        "description" => "imported",
        "sensitive" => "Not Sensitive",
        "status" => "To Do",
        "license plates" => "BULK-1, BULK-2"
      }, project)

      assert Enum.sort(vocabulary(project.id, attr_id)) == ["BULK-1", "BULK-2"]
    end
  end

  describe "get_attribute/2 option injection" do
    test "injects in-use values as options for user-defined-options project attributes" do
      {project, attr_id} = project_with_open_attribute(options: ["PREDEFINED"])
      attribute = Attribute.get_attribute(attr_id, project: project)

      media = media_fixture(%{project_id: project.id})

      {:ok, _} = Material.update_media_attribute_internal(media, attribute, ["IN-USE-PLATE"])

      Material.invalidate_attribute_values_cache()

      injected = Attribute.get_attribute(attr_id, project: project)
      options = Attribute.options(injected)

      assert "IN-USE-PLATE" in options
      # Injection must merge with, not replace, the predefined options.
      assert "PREDEFINED" in options
      assert Enum.uniq(options) == options
    end

    test "leaves closed project attributes' options untouched" do
      project = project_fixture()

      {:ok, project} =
        Projects.update_project(project, %{
          "attributes" => %{
            "0" => %{
              "name" => "Impact",
              "type" => "multi_select",
              "options_json" => Jason.encode!(["Structure"])
            }
          }
        })

      attr = project.attributes |> Enum.find(&(&1.name == "Impact"))

      assert Attribute.options(Attribute.get_attribute(attr.id, project: project)) == ["Structure"]
    end
  end
end
