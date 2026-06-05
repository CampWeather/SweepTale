using Godot;
using System;

public partial class pick_up_trash : RayCast3D
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

				if (objekTertabrak.IsInGroup("Sampah"))
				{
					GD.Print("Memungut sampah: " + objekTertabrak.Name);
					objekTertabrak.QueueFree();
				}
			}
			else
			{
				GD.Print("Tidak ada objek di depan.");
			}
		}
	}
}
