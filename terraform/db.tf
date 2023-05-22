resource "aws_db_instance" "quizzey_db" {
  allocated_storage      = 20
  db_name                = "quizzeydb"
  engine                 = "mysql"
  engine_version         = "8.0.32"
  instance_class         = "db.t3.micro"
  username               = var.username
  password               = var.password
  parameter_group_name   = "default.mysql8.0.32"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.quizzey_db_subnet_group.id //passing in subnet group with list of subnets this db will live in.
  vpc_security_group_ids = [aws_security_group.db_sg.id]                  //passing in the db security group created for db in VPC.
}
