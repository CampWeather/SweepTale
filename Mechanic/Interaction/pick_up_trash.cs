using Godot;
using System;

public partial class pick_up_trash : RayCast3D
{
	[Export] public Node3D PosisiPegang;

	private Node3D _objekDiPegang = null;

	public override void _Ready()
	{
		Enabled = true;
	}

	public override void _Input(InputEvent @event)
	{
		if (@event.IsActionPressed("interact"))
		{
			if (_objekDiPegang == null)
			{
				if (IsColliding())
				{
					Node3D target = (Node3D)GetCollider();
					if (target.IsInGroup("Sampah"))
					{
						AmbilObjek(target);
					}
				}
			}
			else
			{
				LepasObjek();
			}
		}
	}

	private void AmbilObjek(Node3D target)
	{
		GD.Print("Membawa sampah: " + target.Name);
		_objekDiPegang = target;

		_objekDiPegang.Reparent(PosisiPegang);

		_objekDiPegang.Position = Vector3.Zero;

		if (_objekDiPegang is CsgShape3D kotakSampah)
		{
			kotakSampah.UseCollision = false;
		}
	}

	private void LepasObjek()
	{
		GD.Print("Melepas sampah: " + _objekDiPegang.Name);

		_objekDiPegang.Reparent(GetTree().CurrentScene);

		if (_objekDiPegang is CsgShape3D kotakSampah)
		{
			kotakSampah.UseCollision = true;
		}

		_objekDiPegang = null;
	}
}
