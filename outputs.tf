output "receiver_url" {
  description = "URL to access the SocketZero receiver"
  value       = "https://${aws_route53_record.ami_socketzero_app.fqdn}"
}

output "receiver_instance_id" {
  description = "EC2 instance ID of the SocketZero receiver"
  value       = aws_instance.socketzero_receiver.id
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.socketzero_receiver.dns_name
}

output "test_server_ip" {
  description = "Private IP of the test web server (accessible through SocketZero tunnel)"
  value       = aws_instance.web_server_test.private_ip
}

output "next_steps" {
  description = "Instructions for using your SocketZero deployment"
  value = <<-EOT
    🎉 SocketZero deployment complete!
    
    📋 Next Steps:
    1. Open SocketZero client application
    2. Add new profile with hostname: ${aws_route53_record.ami_socketzero_app.fqdn}
    3. Test the tunnel by visiting: http://web-server.apps.socketzero.com
    4. You should see: "Hello World from [hostname]"
    
    📚 Documentation: See docs/ folder for detailed configuration options
  EOT
} 