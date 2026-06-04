using Godot;
using System;

public partial class InteractionController : RayCast3D
{
	public override void _Ready()
	{
		Enabled = true; 
	}

	public override void _Input(InputEvent @event)
	{
		if (@event.IsActionPressed("interact"))
		{
			if (IsColliding())
			{
				Node3D objekTertabrak = (Node3D)GetCollider();

				GD.Print("Memungut sampah: " + objekTertabrak.Name);

				objekTertabrak.QueueFree();
			}
			else
			{
				GD.Print("Tidak ada objek di depan.");
			}
		}
	}
}
