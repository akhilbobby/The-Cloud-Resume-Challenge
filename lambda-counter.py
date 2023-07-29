import json
import boto3
import os

def lambda_handler(event: any, context: any):
    user = event['user']
    visit_count: int = 0
    
    #create a dynamodb client
    dynamodb = boto3.resource("dynamodb")
    #table_name = "db-visit-count"
    #instead of hardcoding table name - use environment variable
    table_name = os.environ["TABLE_NAME"]

    #create table object
    table = dynamodb.Table(table_name)

    #get current visit count
    response = table.get_item(Key={"user": user})
    if "Item" in response:
        visit_count = response ["Item"]["count"]

    #increment count
    visit_count += 1
    message = f"Hello {user}. Visit count is {visit_count}"

    #write visit count back to table
    table.put_item(Item = {"user": user, "count": visit_count})

    return{
        "message": message
    }

# #to test the function locally

# if __name__ == "__main__":
#     event = {"user": "aghil_local"}
#     print(lambda_handler(event, None))


