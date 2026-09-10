using Bck.Api.Features.Auth;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Xunit;

namespace Bck.Api.Tests;

public sealed class DeviceManagementServiceTests
{
    private static DeviceManagementService Service() => new(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"ConnectionStrings:Postgres",Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION")}}).Build());

    [Fact]
    public async Task List_is_scoped_to_group()
    {
        var cs=Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION"); if(string.IsNullOrWhiteSpace(cs)) return;
        await using var c=new NpgsqlConnection(cs);await c.OpenAsync();
        var ga=Guid.NewGuid();var gb=Guid.NewGuid();var da=Guid.NewGuid();var db=Guid.NewGuid();
        await using(var q=new NpgsqlCommand("insert into bck_group(id,name) values($1,'A'),($2,'B'); insert into device(id,group_id,name,platform,device_mode) values($3,$1,'A1','ANDROID','PERSONAL'),($4,$2,'B1','ANDROID','SHARED')",c)){q.Parameters.AddWithValue(ga);q.Parameters.AddWithValue(gb);q.Parameters.AddWithValue(da);q.Parameters.AddWithValue(db);await q.ExecuteNonQueryAsync();}
        var items=await Service().ListAsync(ga,default);
        Assert.Contains(items,x=>x.Id==da);Assert.DoesNotContain(items,x=>x.Id==db);
    }

    [Fact]
    public async Task Changing_mode_disables_quick_access_and_bumps_security_version()
    {
        var cs=Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION"); if(string.IsNullOrWhiteSpace(cs)) return;
        await using var c=new NpgsqlConnection(cs);await c.OpenAsync();var g=Guid.NewGuid();var u=Guid.NewGuid();var d=Guid.NewGuid();
        await using(var q=new NpgsqlCommand("insert into bck_group(id,name) values($1,'A'); insert into bck_user(id,group_id,name,profile,password_hash) values($2,$1,'Admin','ADMIN','x'); insert into device(id,group_id,name,platform,device_mode) values($3,$1,'Celular','ANDROID','PERSONAL'); insert into device_user(device_id,user_id,quick_access_enabled) values($3,$2,true)",c)){q.Parameters.AddWithValue(g);q.Parameters.AddWithValue(u);q.Parameters.AddWithValue(d);await q.ExecuteNonQueryAsync();}
        Assert.True(await Service().ChangeModeAsync(g,d,u,"SHARED",default));
        await using var check=new NpgsqlCommand("select d.device_mode,d.security_version,du.quick_access_enabled from device d join device_user du on du.device_id=d.id where d.id=$1",c);check.Parameters.AddWithValue(d);await using var r=await check.ExecuteReaderAsync();Assert.True(await r.ReadAsync());Assert.Equal("SHARED",r.GetString(0));Assert.Equal(2,r.GetInt32(1));Assert.False(r.GetBoolean(2));
    }

    [Fact]
    public async Task Principal_device_cannot_be_revoked()
    {
        var cs=Environment.GetEnvironmentVariable("BCK_POSTGRES_CONNECTION"); if(string.IsNullOrWhiteSpace(cs)) return;
        await using var c=new NpgsqlConnection(cs);await c.OpenAsync();var g=Guid.NewGuid();var u=Guid.NewGuid();var d=Guid.NewGuid();
        await using(var q=new NpgsqlCommand("insert into bck_group(id,name) values($1,'A'); insert into bck_user(id,group_id,name,profile,password_hash) values($2,$1,'Admin','ADMIN','x'); insert into device(id,group_id,name,platform,device_mode,is_principal) values($3,$1,'Principal','ANDROID','PERSONAL',true)",c)){q.Parameters.AddWithValue(g);q.Parameters.AddWithValue(u);q.Parameters.AddWithValue(d);await q.ExecuteNonQueryAsync();}
        Assert.False(await Service().RevokeAsync(g,d,u,default));
    }
}
